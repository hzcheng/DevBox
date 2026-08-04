#!/bin/bash

set -eo pipefail

# Dev user configuration (passed via environment from docker-compose)
DEV_USER="${DEV_USER:-root}"
DEV_HOME="${DEV_HOME:-/root}"
DEV_GRANT_SUDO="${DEV_GRANT_SUDO:-false}"

# ============================================
# 日志工具函数
# ============================================
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Return the persistent marker for a specific development-user identity.
dev_home_ownership_marker() {
    local uid=$1
    local gid=$2
    printf '%s/.cache/devbox/ownership-initialized-%s-%s\n' \
        "${DEV_HOME}" "${uid}" "${gid}"
}

# ============================================
# 开发用户初始化
# ============================================
setup_dev_user() {
    [ "${DEV_USER}" = "root" ] && return 0

    log_info "Setting up dev user: ${DEV_USER} (home: ${DEV_HOME})"

    # Ensure home directory exists (volume may be empty on first run)
    mkdir -p "${DEV_HOME}"

    # First-volume-boot only: recursively fix ownership of pre-existing root-owned
    # files. The UID/GID-keyed sentinel lives in DEV_HOME so it survives container
    # recreation, while a volume reset or identity change triggers initialization.
    local dev_uid dev_gid sentinel
    dev_uid=$(id -u "${DEV_USER}")
    dev_gid=$(id -g "${DEV_USER}")
    sentinel=$(dev_home_ownership_marker "${dev_uid}" "${dev_gid}")
    if [ ! -f "${sentinel}" ]; then
        log_info "First boot: fixing ownership of ${DEV_HOME} recursively (this may take a moment)..."
        # Use find to skip read-only bind mounts (e.g. ~/.ssh mounted with :ro).
        find "${DEV_HOME}" -mount -exec chown "${DEV_USER}:${DEV_USER}" {} + 2>/dev/null || true
        install -d -m 0755 -o "${DEV_USER}" -g "${DEV_USER}" "$(dirname "${sentinel}")"
        touch "${sentinel}"
        chown "${DEV_USER}:${DEV_USER}" "${sentinel}"
        log_info "Ownership fixed. Subsequent boots will skip this step."
    else
        # Subsequent boots: ensure just the top-level home dir has correct ownership.
        chown "${DEV_USER}:${DEV_USER}" "${DEV_HOME}"
    fi

    # Ensure projects directory exists and is owned by the dev user
    mkdir -p "${DEV_HOME}/projects"
    chown "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/projects"

    # Populate shell dotfiles from /etc/skel if missing (volume mount wipes them).
    for skel_file in /etc/skel/.*; do
        [ -f "${skel_file}" ] || continue
        dest="${DEV_HOME}/${skel_file##/etc/skel/}"
        if [ ! -e "${dest}" ]; then
            cp "${skel_file}" "${dest}"
            chown "${DEV_USER}:${DEV_USER}" "${dest}"
        fi
    done

    # Inject devbox prompt into ~/.bashrc if not already present.
    # /etc/profile.d/ only runs for login shells; VS Code terminals are non-login interactive,
    # so we source the prompt script from ~/.bashrc instead.
    local bashrc="${DEV_HOME}/.bashrc"
    if [ -f "${bashrc}" ] && ! grep -q 'devbox-prompt' "${bashrc}"; then
        printf '\n# devbox prompt (git branch + newline)\n[ -f /etc/profile.d/devbox-prompt.sh ] && . /etc/profile.d/devbox-prompt.sh\n' >> "${bashrc}"
        chown "${DEV_USER}:${DEV_USER}" "${bashrc}"
    fi

    # Symlink global tmux.conf into user home (Dockerfile copies it to /etc/tmux.conf)
    if [ -f /etc/tmux.conf ] && [ ! -e "${DEV_HOME}/.tmux.conf" ]; then
        ln -sf /etc/tmux.conf "${DEV_HOME}/.tmux.conf"
        chown -h "${DEV_USER}:${DEV_USER}" "${DEV_HOME}/.tmux.conf"
    fi

    # Add dev user to the docker group using the host socket's actual GID.
    # The GID is host-specific and unknown at image build time, so we handle it here.
    # We add docker as a supplementary group AND inject a newgrp call into ~/.bashrc so
    # that every new terminal (including VS Code integrated terminals, which are forked
    # from a process that predates this setup) automatically re-enters the docker group.
    local docker_gid
    docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)
    if [ -n "${docker_gid}" ] && [ "${docker_gid}" != "0" ]; then
        groupadd --gid "${docker_gid}" docker 2>/dev/null || true
        usermod -aG docker "${DEV_USER}" 2>/dev/null || true
        log_info "Added ${DEV_USER} to docker group (gid=${docker_gid})"

        # Inject newgrp into ~/.bashrc so every new terminal picks up the docker group.
        # Without this, editor terminals may inherit process groups from a long-lived server,
        # which was started before setup_dev_user ran and does not have docker in its groups.
        local bashrc="${DEV_HOME}/.bashrc"
        if [ -f "${bashrc}" ] && ! grep -q 'newgrp docker' "${bashrc}"; then
            printf '\n# Re-enter docker group so VS Code terminals can access /var/run/docker.sock\nif ! id -nG 2>/dev/null | grep -qw docker; then exec newgrp docker; fi\n' >> "${bashrc}"
            chown "${DEV_USER}:${DEV_USER}" "${bashrc}"
            log_info "Injected newgrp docker into ${bashrc}"
        fi
    fi

}

# ============================================
# Kimi CLI CodeWiz provider 配置
# ============================================
setup_kimi_codewiz() {
    local python_bin="${KIMI_CONFIGURE_PYTHON:-/usr/local/share/uv-tools/kimi-cli/bin/python}"
    local -a command

    if [ ! -x "${python_bin}" ]; then
        log_warn "Kimi Python not found at ${python_bin}, skipping Kimi CodeWiz config"
        return 0
    fi

    if [ "${DEV_USER}" != "root" ]; then
        command=(env HOME="${DEV_HOME}" gosu "${DEV_USER}" "${python_bin}" - "${DEV_HOME}")
    else
        command=(env HOME="${DEV_HOME}" "${python_bin}" - "${DEV_HOME}")
    fi

    if "${command[@]}" <<'PY'
import os
import sys
import tempfile
from pathlib import Path

import tomlkit


home = Path(sys.argv[1])
config_dir = home / ".kimi"
config_path = config_dir / "config.toml"
config_dir.mkdir(parents=True, exist_ok=True)

if config_path.exists():
    document = tomlkit.parse(config_path.read_text(encoding="utf-8"))
else:
    document = tomlkit.document()

document["default_model"] = "codewiz/kimi-k3"
document["default_thinking"] = True

providers = document.get("providers")
if not isinstance(providers, dict):
    providers = tomlkit.table()
    document["providers"] = providers
providers["codewiz"] = {
    "type": "kimi",
    "base_url": "http://127.0.0.1:8089/v1",
    "api_key": "dummy",
}

models = document.get("models")
if not isinstance(models, dict):
    models = tomlkit.table()
    document["models"] = models
models["codewiz/kimi-k3"] = {
    "provider": "codewiz",
    "model": "kimi-k3",
    "max_context_size": 1000000,
    "capabilities": ["thinking", "image_in"],
}

fd, temp_name = tempfile.mkstemp(prefix=".config.toml.", dir=config_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as temp_file:
        temp_file.write(tomlkit.dumps(document))
        temp_file.flush()
        os.fsync(temp_file.fileno())
    os.chmod(temp_name, 0o600)
    os.replace(temp_name, config_path)
except BaseException:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    raise
PY
    then
        log_info "Kimi CLI configured for CodeWiz K3"
    else
        log_warn "Failed to configure Kimi CLI for CodeWiz K3; existing config preserved"
    fi
}

# ============================================
# 旧环境变量兼容性警告
# ============================================
_warn_deprecated_env_vars() {
    local deprecated_vars=""
    for var in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL OPENAI_API_KEY OPENAI_BASE_URL; do
        if [ -n "${!var:-}" ]; then
            deprecated_vars="${deprecated_vars}${deprecated_vars:+, }${var}"
        fi
    done
    if [ -n "$deprecated_vars" ]; then
        log_warn "检测到已弃用的环境变量: ${deprecated_vars}"
        log_warn "Claude Code / Codex 的 endpoint 配置已迁移到 cc-switch，请通过以下命令管理："
        log_warn "  cc-switch provider list          # 查看可用 provider"
        log_warn "  cc-switch provider switch <id>   # 切换 provider"
        log_warn "  cc-switch provider add           # 添加自定义 provider"
        log_warn "如需持久化自定义 provider，请修改 devbox/config/cc-switch/providers-patch.sql"
    fi
}

# ============================================
# cc-switch provider 配置（codewiz-proxy 模型切换）
# ============================================
setup_cc_switch_providers() {
    local db="${DEV_HOME}/.cc-switch/cc-switch.db"
    local patch="/usr/local/share/cc-switch-providers.sql"

    if [ ! -f "$patch" ]; then
        log_warn "cc-switch provider patch not found at ${patch}, skipping"
        return 0
    fi

    # Initialize cc-switch DB if missing (run as dev user to avoid root-owned files)
    if [ ! -f "$db" ]; then
        mkdir -p "$(dirname "$db")"
        if [ "${DEV_USER}" != "root" ] && command -v gosu >/dev/null 2>&1; then
            gosu "${DEV_USER}" cc-switch provider list > /dev/null 2>&1 || true
            chown -R "${DEV_USER}:${DEV_USER}" "$(dirname "$db")"
        else
            cc-switch provider list > /dev/null 2>&1 || true
            chown -R "${DEV_USER}:${DEV_USER}" "$(dirname "$db")"
        fi
    fi

    # Apply provider patch (INSERT OR IGNORE, preserves existing records including is_current)
    if [ -f "$db" ]; then
        if _CC_SWITCH_DB="$db" _CC_SWITCH_PATCH="$patch" python3 -c "
import sqlite3, sys, os
try:
    db = os.environ['_CC_SWITCH_DB']
    patch = os.environ['_CC_SWITCH_PATCH']
    conn = sqlite3.connect(db)
    with open(patch, encoding='utf-8') as f:
        conn.executescript(f.read())
    conn.commit()
    conn.close()
except Exception as e:
    print(f'[cc-switch] ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"; then
            log_info "cc-switch providers configured"
        else
            log_warn "Failed to apply cc-switch provider patch"
        fi
    fi
}

# ============================================
# Tmux 插件安装（session 持久化，运行时下载无需重建镜像）
# ============================================
setup_tmux_plugins() {
    local tmux_dir="${DEV_HOME}/.tmux"
    local tmux_plugins_dir="${tmux_dir}/plugins"
    mkdir -p "${tmux_plugins_dir}"

    # Sync tmux.conf from the bind-mounted repo so changes don't require image rebuild.
    # The repo is mounted at ${DEV_HOME}/projects/DevBox via docker-compose.
    local repo_tmux_conf="${DEV_HOME}/projects/DevBox/devbox/tmux.conf"
    if [ -f "${repo_tmux_conf}" ]; then
        cp -f "${repo_tmux_conf}" /etc/tmux.conf
        log_info "Synced tmux.conf from repo"
    fi

    install_tmux_plugin() {
        local repo_name="$1"
        local plugin_dir="${tmux_plugins_dir}/${repo_name}"
        if [ -d "${plugin_dir}/.git" ]; then
            return 0
        fi

        log_info "Installing tmux plugin: ${repo_name}"
        local base_url="https://github.com/tmux-plugins"
        if git clone --depth=1 "${base_url}/${repo_name}.git" "${plugin_dir}" 2>/dev/null; then
            return 0
        elif git clone --depth=1 "https://ghp.ci/${base_url}/${repo_name}.git" "${plugin_dir}" 2>/dev/null; then
            return 0
        else
            log_warn "Failed to install tmux plugin: ${repo_name}. Session persistence will not be available."
            rm -rf "${plugin_dir}"
            return 0
        fi
    }

    install_tmux_plugin "tpm" || true
    install_tmux_plugin "tmux-resurrect" || true
    install_tmux_plugin "tmux-continuum" || true

    # Ensure the entire ~/.tmux tree is owned by dev user so resurrect/continuum
    # can create ~/.tmux/resurrect/ and write save files.
    if [ "${DEV_USER}" != "root" ] && [ -d "${tmux_dir}" ]; then
        chown -R "${DEV_USER}:${DEV_USER}" "${tmux_dir}"
    fi
}

# ============================================
# VS Code Dev Containers bridge 清理
# ============================================
setup_vscode_bridge_reaper() {
    case "${VSCODE_BRIDGE_REAPER_ENABLED:-true}" in
        false|FALSE|0|no|NO|off|OFF)
            log_info "VS Code bridge reaper disabled"
            return 0
            ;;
    esac

    local reaper=/usr/local/bin/vscode-bridge-reaper
    if [ ! -x "${reaper}" ]; then
        log_warn "VS Code bridge reaper not found at ${reaper}, skipping"
        return 0
    fi

    log_info "Starting VS Code bridge reaper (interval=${VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS:-600}s, min_age=${VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS:-1800}s)"
    if [ "${DEV_USER}" != "root" ]; then
        HOME="${DEV_HOME}" gosu "${DEV_USER}" "${reaper}" &
    else
        "${reaper}" &
    fi
}

# ============================================
# SSH 服务管理
# ============================================
setup_ssh() {
    log_info "Setting up SSH service..."

    mkdir -p /var/run/sshd

    # Configure SSH public key for the dev user (root or non-root)
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

    # Start SSH daemon in background
    /usr/sbin/sshd -D &
    log_info "SSH service started on port 22"
}

# ============================================
# Git 配置
# ============================================
setup_git() {
    log_info "Configuring Git..."

    # Run as dev user so ~/.gitconfig lands in DEV_HOME. Use a single subshell to
    # avoid forking gosu once per config key.
    local as_dev_user=""
    [ "${DEV_USER}" != "root" ] && as_dev_user="gosu ${DEV_USER}"

    ${as_dev_user} bash -c "
        [ -n '${GIT_USER_NAME}' ]  && git config --global user.name  '${GIT_USER_NAME}'
        [ -n '${GIT_USER_EMAIL}' ] && git config --global user.email '${GIT_USER_EMAIL}'
        git config --global init.defaultBranch main
        git config --global credential.helper store
    "
    [ -n "${GIT_USER_NAME}" ]  && log_info "Git user.name set to: ${GIT_USER_NAME}"
    [ -n "${GIT_USER_EMAIL}" ] && log_info "Git user.email set to: ${GIT_USER_EMAIL}"
}

# ============================================
# Claude + Codex Proxy 启动（共用同一个 proxy，端口 8089）
# ============================================
setup_claude_proxy() {
    if [ "${DEV_USER}" != "root" ]; then
        # Run as dev user so HOME resolves to DEV_HOME (where codewiz auth.json lives)
        HOME="${DEV_HOME}" gosu "${DEV_USER}" /usr/local/bin/start-claude-proxy.sh \
            2>&1 | while IFS= read -r line; do log_info "${line}"; done || true
    else
        /usr/local/bin/start-claude-proxy.sh \
            2>&1 | while IFS= read -r line; do log_info "${line}"; done || true
    fi
    # Proxy health check only; endpoint config is managed by cc-switch provider settings
    if ! curl -sf --max-time 2 "http://127.0.0.1:8089" >/dev/null 2>&1; then
        log_warn "codewiz-proxy not responding on port 8089"
    fi
}

# ============================================
# 主函数
# ============================================
main() {
    log_info "=========================================="
    log_info "Starting DevBox services..."
    log_info "=========================================="

    # 0. 初始化开发用户（必须最先，其他函数依赖 DEV_HOME 目录已就绪）
    setup_dev_user

    # 0.2 配置 Kimi CLI 使用本地 CodeWiz proxy 的 K3 模型
    setup_kimi_codewiz

    # 0.4 旧环境变量兼容性警告
    _warn_deprecated_env_vars

    # 0.5 配置 cc-switch providers（codewiz-proxy 模型切换）
    setup_cc_switch_providers

    # 0.6 安装 tmux 插件（运行时下载，无需重建镜像）
    setup_tmux_plugins

    # 0.7 定时清理失联的 VS Code Dev Containers bridge helper
    setup_vscode_bridge_reaper

    # 1. 启动 SSH 服务
    setup_ssh

    # 2. 配置 Git
    setup_git

    # 3. 启动 Claude/Codex proxy
    setup_claude_proxy

    log_info "=========================================="
    log_info "All services started successfully!"
    log_info "SSH: port 22"
    log_info "=========================================="

    # 9. 保持容器运行，等待所有后台进程
    wait
}

# 执行主函数
main "$@"
