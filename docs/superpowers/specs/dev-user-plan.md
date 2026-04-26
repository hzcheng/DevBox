# Plan: 支持 .env 中指定非 root 开发用户

## Context

当前 devbox 容器以 root 身份运行所有服务。用户希望通过 `.env` 中的 `DEV_USER` 变量指定非 root 用户（如 `hzcheng`），并可通过 `DEV_GRANT_SUDO` 控制 sudo 权限。

**约束**：
- 不能重启当前正在运行的 dev container（修改只影响下次重建镜像/重启容器时生效）
- 以 root 运行的所有功能都要在非 root 情况下正常工作
- 现有 volume/bind-mount 数据绝对安全（不丢失、不破坏）
- 挂载为非 root 账号时，历史文件可正常读取和写入
- VSCode open in container 和 code-server（浏览器）均以指定用户身份登录

## 最终决策

| 问题 | 决策 |
|------|------|
| 用户创建时机 | **Dockerfile build-arg** 创建用户（需重建镜像） |
| entrypoint 运行身份 | 仍以 root 运行（sshd/dpkg 需要 root），code-server 用 gosu 切换 |
| sudo 控制 | `DEV_GRANT_SUDO=true/false` |
| dev-root 挂载 | 挂到 `${DEV_HOME}`，**首次启动 sentinel 文件标记 + chown -R**（方案 G） |
| 挂载路径 | `/Projects` → `${DEV_HOME}/projects`，`/Projects/DevBox` → `${DEV_HOME}/projects/DevBox` |
| 配置路径 | start-services.sh 用 `${DEV_HOME}` 替换 `/root` 硬编码 |
| compose 路径 | 用 `${DEV_HOME}` 替换 compose 里的 `/root` |
| bazel-download 预缓存 | 删除预下载步骤（Bazel 自动下载，不影响 build） |
| bazel 二进制路径 | **无需改动**：installer 默认 prefix=/usr/local，bazel 已在 /usr/local/bin |
| kimi | Dockerfile 安装时设 UV_TOOL_DIR=/usr/local/share/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin |
| devcontainer.json | `workspaceFolder` 和 `remoteUser` 同步修改；`postStartCommand` 不动 |

## 自检问题及解决方案

| # | 问题 | 解决方案 |
|---|------|---------|
| 1 | ~~Bazel 7.4.1 安装到 `/root/bin/bazel`~~ | **不存在**：installer 默认 prefix=/usr/local，已在 /usr/local/bin/bazel |
| 2 | `/root/bazel-download/` 父目录 700，非 root 不可进入 | 删除预缓存下载步骤（Bazel build 时自动下载，无影响） |
| 3 | 插件以 root 安装到 `/root/.local/share/`，gosu 启动后找不到 | 设全局 `CODE_SERVER_CMD`，所有调用函数均使用该变量 |
| 4 | auto-update 后 `restart_code_server` 不走 gosu，变回 root | `start_code_server` 统一用 `${CODE_SERVER_CMD}` 包装，restart 自动继承 |
| 5 | SSH authorized_keys 硬编码写到 `/root/.ssh/` | `setup_ssh` 改用 `${DEV_HOME}/.ssh/` + chown |
| 6 | `git config --global` 以 root 运行，写到 `/root/.gitconfig` | `setup_git` 改用 `gosu ${DEV_USER} git config` |
| 7 | claude proxy 以 root 运行，HOME=/root 找不到 codewiz auth.json | `setup_claude_proxy` 改用 `HOME=${DEV_HOME} gosu ${DEV_USER}` |
| 8 | `setup_code_server_config` 硬编码 `/root/.config/code-server` | 改用 `${DEV_HOME}/.config/code-server` |
| 9 | `ENV PATH="/root/.local/bin:..."` 对非 root 无效 | `start_code_server` 启动时注入 `${DEV_HOME}/.local/bin` 到 PATH |
| 10 | DEV_USER 不在 docker 组，无法操作 docker socket | `setup_dev_user` 里动态读取 socket GID，创建 docker 组后加入用户 |
| 11 | dev-root volume 历史文件属 root，非 root 无法写 | 方案 G：首次启动 `chown -R`，sentinel 文件防重复执行 |
| 12 | kimi 安装在 `/root/.local/share/uv/tools/`，非 root 无法访问 | Dockerfile 安装时设 `UV_TOOL_DIR` / `UV_TOOL_BIN_DIR` 到 /usr/local 下 |

---

## 文件改动清单

### 1. `/Projects/DevBox/.env`

完善已有占位符：
```bash
DEV_USER=root          # 改为目标用户名，如 hzcheng
DEV_HOME=/root         # 改为对应 home，如 /home/hzcheng
DEV_GRANT_SUDO=false   # 新增：true = 给该用户 NOPASSWD sudo
DEV_UID=0              # 新增：与宿主机一致的 UID（root 时保持 0）
DEV_GID=0              # 新增：与宿主机一致的 GID
```

### 2. `/Projects/DevBox/devbox/docker-compose.yml`

#### build.args 新增
```yaml
args:
  DEV_USER: ${DEV_USER:-root}
  DEV_HOME: ${DEV_HOME:-/root}
  DEV_UID: ${DEV_UID:-0}
  DEV_GID: ${DEV_GID:-0}
  DEV_GRANT_SUDO: ${DEV_GRANT_SUDO:-false}
```

#### environment 新增
```yaml
- DEV_USER=${DEV_USER:-root}
- DEV_HOME=${DEV_HOME:-/root}
- DEV_GRANT_SUDO=${DEV_GRANT_SUDO:-false}
```

#### volumes 改动
```yaml
- ${DEV_ROOT:-dev-root}:${DEV_HOME:-/root}
- ${DEV_PROJECTS:-dev-projects}:${DEV_HOME:-/root}/projects
- ..:${DEV_HOME:-/root}/projects/DevBox:cached
- ./config/code-server/User/keybindings.json:${DEV_HOME:-/root}/.local/share/code-server/User/keybindings.json:cached
- ./config/code-server/User/settings.json:${DEV_HOME:-/root}/.local/share/code-server/User/settings.json:cached
- ./config/code-server/User/projects.json:${DEV_HOME:-/root}/.local/share/code-server/User/globalStorage/alefragnani.project-manager/projects.json:cached
```

### 3. `/Projects/DevBox/devbox/Dockerfile`

#### devbox stage 改动

**① 安装 gosu**（加入 openssh-server 那行）：
```dockerfile
RUN apt-get install -y --no-install-recommends openssh-server gosu && \
    ...
```

**② tmux.conf 改为全局路径**：
```dockerfile
# 删除：COPY devbox/tmux.conf /root/.tmux.conf
# 改为：
COPY devbox/tmux.conf /etc/tmux.conf
RUN sed -i 's/\r$//' /etc/tmux.conf
```

**③ 删除** `RUN mkdir -p /root/.config/code-server`（改由 start-services.sh 创建）

**④ kimi 安装改为全局路径**（问题 12）：
```dockerfile
# 现有（base stage）：
ENV PATH="/root/.local/bin:$PATH"
RUN curl -fsSL https://code.kimi.com/install.sh | bash

# 改为：
ENV UV_TOOL_DIR=/usr/local/share/uv-tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin
# 删除 ENV PATH="/root/.local/bin:$PATH"（kimi 已在 /usr/local/bin，无需此行）
RUN curl -fsSL https://code.kimi.com/install.sh | bash
```

**⑤ 新增用户创建逻辑**（在 EXPOSE 前，devbox stage 末尾）：
```dockerfile
ARG DEV_USER=root
ARG DEV_HOME=/root
ARG DEV_UID=0
ARG DEV_GID=0
ARG DEV_GRANT_SUDO=false

RUN if [ "${DEV_USER}" != "root" ]; then \
      if [ -n "${DEV_GID}" ] && [ "${DEV_GID}" != "0" ]; then \
        groupadd --gid "${DEV_GID}" "${DEV_USER}" 2>/dev/null || groupadd "${DEV_USER}" 2>/dev/null || true; \
      else \
        groupadd "${DEV_USER}" 2>/dev/null || true; \
      fi && \
      useradd_args="--home-dir ${DEV_HOME} --shell /bin/bash" && \
      if [ -n "${DEV_UID}" ] && [ "${DEV_UID}" != "0" ]; then \
        useradd_args="${useradd_args} --uid ${DEV_UID}"; \
      fi && \
      if getent group "${DEV_USER}" >/dev/null 2>&1; then \
        useradd_args="${useradd_args} --gid ${DEV_USER}"; \
      fi && \
      useradd ${useradd_args} "${DEV_USER}" && \
      if [ "${DEV_GRANT_SUDO}" = "true" ]; then \
        echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${DEV_USER}" && \
        chmod 0440 /etc/sudoers.d/"${DEV_USER}"; \
      fi; \
    fi
```

> **注意**：docker 组不在 Dockerfile 里创建，因为宿主机 docker socket 的 GID 在构建时未知，需在运行时动态处理（见 start-services.sh `setup_dev_user`）。

#### devbox-red stage 改动

**删除** `/root/bazel-download` 相关预下载（问题 2），保留 bazel installer 安装（prefix 已是 /usr/local，无需修改）：
```dockerfile
# 删除这两行 curl：
# curl ... -o /root/bazel-download/cpython-3.11.7+...
# curl ... -o /root/bazel-download/bazel-skylib-1.6.1.tar.gz

# 保留（不变）：
RUN curl ... -o /tmp/bazel-7.4.1-installer-linux-x86_64.sh && \
    bash /tmp/bazel-7.4.1-installer-linux-x86_64.sh && \
    bazel --version && \
    rm -f /tmp/bazel-7.4.1-installer-linux-x86_64.sh
```

### 4. `/Projects/DevBox/devbox/start-services.sh`

#### 开头新增变量初始化
```bash
DEV_USER="${DEV_USER:-root}"
DEV_HOME="${DEV_HOME:-/root}"
DEV_GRANT_SUDO="${DEV_GRANT_SUDO:-false}"

# 全局 code-server 命令（非 root 时用 gosu 包装，所有函数统一使用）
if [ "${DEV_USER}" != "root" ]; then
    CODE_SERVER_CMD="gosu ${DEV_USER} code-server"
else
    CODE_SERVER_CMD="code-server"
fi
```

#### 新增 `setup_dev_user()` — 在 main() 最先调用
```bash
setup_dev_user() {
    [ "${DEV_USER}" = "root" ] && return 0

    log_info "Setting up dev user: ${DEV_USER} (home: ${DEV_HOME})"

    # 创建 home 目录（volume 挂载后可能为空或已有 root 文件）
    mkdir -p "${DEV_HOME}"

    # 方案 G：首次启动才执行 chown -R，sentinel 防重复
    local sentinel="${DEV_HOME}/.devbox-initialized"
    if [ ! -f "${sentinel}" ]; then
        log_info "First boot: fixing ownership of ${DEV_HOME}..."
        chown -R "${DEV_USER}:${DEV_USER}" "${DEV_HOME}"
        touch "${sentinel}"
        log_info "Ownership fixed. Subsequent boots will skip this step."
    fi

    # 创建 projects 子目录（若不存在）
    mkdir -p "${DEV_HOME}/projects"
    chown "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/projects"

    # tmux.conf symlink（Dockerfile 已 COPY 到 /etc/tmux.conf）
    if [ -f /etc/tmux.conf ] && [ ! -e "${DEV_HOME}/.tmux.conf" ]; then
        ln -sf /etc/tmux.conf "${DEV_HOME}/.tmux.conf"
        chown -h "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.tmux.conf"
    fi

    # 动态创建 docker 组并加入用户（问题 10）
    # 宿主机 docker socket GID 在构建时未知，运行时动态处理
    local docker_gid
    docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)
    if [ -n "${docker_gid}" ] && [ "${docker_gid}" != "0" ]; then
        groupadd --gid "${docker_gid}" docker 2>/dev/null || true
        usermod -aG docker "${DEV_USER}" 2>/dev/null || true
        log_info "Added ${DEV_USER} to docker group (gid=${docker_gid})"
    fi
}
```

#### 修改 `setup_ssh()` — 问题 5
```bash
setup_ssh() {
    log_info "Setting up SSH service..."
    mkdir -p /var/run/sshd

    if [ -n "$SSH_PUBLIC_KEY" ]; then
        log_info "Configuring SSH public key authentication for ${DEV_USER}..."
        mkdir -p "${DEV_HOME}/.ssh"
        echo "$SSH_PUBLIC_KEY" > "${DEV_HOME}/.ssh/authorized_keys"
        chmod 700 "${DEV_HOME}/.ssh"
        chmod 600 "${DEV_HOME}/.ssh/authorized_keys"
        if [ "${DEV_USER}" != "root" ]; then
            chown -R "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.ssh"
        fi
    fi

    /usr/sbin/sshd -D &
    log_info "SSH service started on port 22"
}
```

#### 修改 `setup_git()` — 问题 6
```bash
setup_git() {
    log_info "Configuring Git..."

    local git_cmd="git"
    [ "${DEV_USER}" != "root" ] && git_cmd="gosu ${DEV_USER} git"

    [ -n "$GIT_USER_NAME" ]  && ${git_cmd} config --global user.name  "$GIT_USER_NAME"
    [ -n "$GIT_USER_EMAIL" ] && ${git_cmd} config --global user.email "$GIT_USER_EMAIL"
    ${git_cmd} config --global init.defaultBranch main
    ${git_cmd} config --global credential.helper store
}
```

#### 修改 `setup_code_server_config()` — 问题 8
```bash
setup_code_server_config() {
    log_info "Setting up code-server configuration..."
    local config_dir="${DEV_HOME}/.config/code-server"
    mkdir -p "${config_dir}"
    cat > "${config_dir}/config.yaml" <<EOF
bind-addr: 0.0.0.0:${CODE_SERVER_PORT:-8080}
auth: ${CODE_SERVER_AUTH:-password}
password: ${CODE_SERVER_PASSWORD:-devbox}
cert: false
EOF
    if [ "${DEV_USER}" != "root" ]; then
        chown -R "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.config"
    fi
}
```

#### 修改 `start_code_server()` — 问题 3、4、9
```bash
start_code_server() {
    log_info "Starting code-server on port ${CODE_SERVER_PORT:-8080}..."

    local config="${DEV_HOME}/.config/code-server/config.yaml"
    local workdir="${DEV_HOME}/projects"

    if [ "${DEV_USER}" != "root" ]; then
        PATH="${DEV_HOME}/.local/bin:${PATH}" \
            gosu "${DEV_USER}" /usr/bin/code-server --config "${config}" "${workdir}" &
    else
        /usr/bin/code-server --config "${config}" "${workdir}" &
    fi
    CODE_SERVER_PID=$!
    log_info "code-server started (PID: ${CODE_SERVER_PID})"
}
```

> **gosu exec 特性**：gosu 使用 exec 执行目标命令，自身进程被替换，`CODE_SERVER_PID` 直接指向 code-server 进程，`kill`/`wait` 均正常工作。

#### 修改 `setup_claude_proxy()` — 问题 7
```bash
setup_claude_proxy() {
    local output
    if [ "${DEV_USER}" != "root" ]; then
        output="$(HOME="${DEV_HOME}" gosu "${DEV_USER}" /usr/local/bin/start-claude-proxy.sh 2>&1)" || true
    else
        output="$(/usr/local/bin/start-claude-proxy.sh 2>&1)" || true
    fi
    while IFS= read -r line; do log_info "${line}"; done <<< "${output}"
    if curl -sf --max-time 2 "http://127.0.0.1:8089" >/dev/null 2>&1; then
        export ANTHROPIC_BASE_URL="http://127.0.0.1:8089"
        export ANTHROPIC_API_KEY="dummy"
    fi
}
```

#### 修改 `install_openvsx_extension()` 和 `install_marketplace_vsix()` — 问题 3
这两个底层函数直接调用 `code-server`，需改用全局 `CODE_SERVER_CMD`：

```bash
install_marketplace_vsix() {
    ...
    # 原：code-server --install-extension "${vsix_path}" --force
    ${CODE_SERVER_CMD} --install-extension "${vsix_path}" --force
    rm -f "${vsix_path}"
    # 原：code-server --list-extensions | grep -Fx "${extension_id}" >/dev/null
    ${CODE_SERVER_CMD} --list-extensions | grep -Fx "${extension_id}" >/dev/null
}

install_openvsx_extension() {
    local extension_id="$1"
    # 原：code-server --install-extension "${extension_id}" --force
    ${CODE_SERVER_CMD} --install-extension "${extension_id}" --force
    # 原：code-server --list-extensions | grep -Fx "${extension_id}" >/dev/null
    ${CODE_SERVER_CMD} --list-extensions | grep -Fx "${extension_id}" >/dev/null
}
```

> `install_extensions_async` 不再需要单独定义 `cs_cmd`，直接删去该局部变量，底层函数已统一使用 `CODE_SERVER_CMD`。

#### `main()` — 在最开头插入
```bash
main() {
    # 0. 初始化开发用户（必须最先，其他函数依赖 DEV_HOME 目录已就绪）
    setup_dev_user

    # 1. 启动 SSH 服务
    setup_ssh
    ...
}
```

### 5. `/Projects/DevBox/devbox/.devcontainer.json`

仅修改两个字段（不支持变量，需与 DEV_USER/DEV_HOME 手动保持一致）：
```json
"workspaceFolder": "/home/hzcheng/projects/DevBox",
"remoteUser": "hzcheng"
```

`postStartCommand` **保持不变**：该命令以 `remoteUser` 身份运行，Shell 自动设置正确的 `HOME`，无需手动指定。

---

## 兼容性保证（DEV_USER=root）

所有改动均有 `[ "${DEV_USER}" = "root" ]` 守卫：
- root 时 `setup_dev_user` 直接 return，所有路径保持 `/root`
- `CODE_SERVER_CMD="code-server"`，行为与修改前完全一致

---

## 验证步骤

1. `.env`：设置 `DEV_USER=hzcheng`, `DEV_HOME=/home/hzcheng`, `DEV_UID=<宿主机uid>`, `DEV_GID=<宿主机gid>`, `DEV_GRANT_SUDO=true`
2. `docker compose build`（仅重建镜像，不影响当前容器）
3. 停止旧容器，`docker compose up` 启动新容器后验证：
   - code-server terminal：`whoami` → `hzcheng`
   - `ls -la /home/hzcheng/` 文件 owner 为 hzcheng
   - `ls /home/hzcheng/projects/DevBox` 挂载正常
   - SSH：`ssh hzcheng@host -p 2222` 成功
   - `bazel --version` 正常（/usr/local/bin/bazel，无需改动）
   - `kimi --version` 正常（/usr/local/bin/kimi，全局安装）
   - `docker ps` 正常（hzcheng 在 docker 组，GID 与宿主机一致）
   - `sudo ls /root` 成功（DEV_GRANT_SUDO=true）
   - `git config user.name` 返回正确值
   - claude proxy 启动，`echo $ANTHROPIC_BASE_URL` 输出正确
   - VSCode open in container 以 hzcheng 登录

---

## 关键文件

| 文件 | 改动要点 |
|------|---------|
| `/Projects/DevBox/.env` | 新增 DEV_GRANT_SUDO / DEV_UID / DEV_GID |
| `/Projects/DevBox/devbox/docker-compose.yml` | DEV_HOME 替换 /root 和 /Projects，新增 build args/env |
| `/Projects/DevBox/devbox/Dockerfile` | gosu 安装；tmux→/etc/tmux.conf；kimi 改 UV_TOOL_DIR/BIN_DIR；用户创建逻辑；删 bazel-download 预下载 |
| `/Projects/DevBox/devbox/start-services.sh` | CODE_SERVER_CMD 全局变量；setup_dev_user()（含动态 docker GID）；所有 /root→${DEV_HOME}；gosu 包装 |
| `/Projects/DevBox/devbox/.devcontainer.json` | workspaceFolder + remoteUser 同步（手动维护） |
