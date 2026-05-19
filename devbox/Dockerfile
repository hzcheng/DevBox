# docker build --no-cache -t hzcheng/devbox:latest -f ./devbox/Dockerfile ./devbox
# docker run -it --rm hzcheng/devbox:latest bash
#
# For mainland China network, build with:
#   docker build --build-arg USE_CN_MIRROR=true -t hzcheng/devbox:latest -f ./devbox/Dockerfile ./devbox

# =============================================================================
# Stage 1: Base image with all development tools
# This stage contains all the heavy dependencies that rarely change
# =============================================================================
# Use Docker Hub mirror for MCR (for mainland China network)
# You can also use: docker.m.daocloud.io/mcr.microsoft.com/vscode/devcontainers/cpp:ubuntu-22.04
FROM mcr.microsoft.com/vscode/devcontainers/cpp:ubuntu-22.04 AS base

# Set to "true" to use mainland China mirrors for faster builds
# Currently supported: Ubuntu apt, Docker apt, NPM registry, Go download, GitHub releases
ARG USE_CN_MIRROR=false

ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG GO_VERSION=latest
ARG TARGETARCH
ARG TARGETARCH_OVERRIDE

ENV GOROOT=/usr/local/go
ENV PATH="${GOROOT}/bin:${PATH}"
ENV TZ="Asia/Shanghai"

# Change timezone and source list for the effective target architecture.
RUN EFFECTIVE_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${EFFECTIVE_ARCH}" ]; then EFFECTIVE_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) EFFECTIVE_ARCH="amd64" ;; \
      amd64) UBUNTU_MIRROR_ROOT="ubuntu" ;; \
      arm64) UBUNTU_MIRROR_ROOT="ubuntu-ports" ;; \
      *) echo "Unsupported target architecture: ${EFFECTIVE_ARCH}" >&2; exit 1 ;; \
    esac && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    if [ "${USE_CN_MIRROR}" = "true" ]; then \
        printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" > /etc/apt/sources.list && \
        printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy-updates main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" >> /etc/apt/sources.list && \
        printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy-backports main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" >> /etc/apt/sources.list; \
    else \
        printf 'deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse\n' > /etc/apt/sources.list && \
        printf 'deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse\n' >> /etc/apt/sources.list && \
        printf 'deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse\n' >> /etc/apt/sources.list; \
    fi

# Prepare for adding repositories
RUN EFFECTIVE_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${EFFECTIVE_ARCH}" ]; then EFFECTIVE_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) EFFECTIVE_ARCH="amd64" ;; \
      amd64|arm64) ;; \
      *) echo "Unsupported target architecture: ${EFFECTIVE_ARCH}" >&2; exit 1 ;; \
    esac && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y \
    software-properties-common ca-certificates wget curl gnupg lsb-release inetutils-ping && \
    # Add LLVM apt repository (use official source with retry)
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    add-apt-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-20 main" && \
    # Add Node.js apt repository (use official source with fallback)
    curl -fsSL https://deb.nodesource.com/setup_current.x | bash - && \
    # Add Docker apt repository
    install -m 0755 -d /etc/apt/keyrings && \
    if [ "${USE_CN_MIRROR}" = "true" ]; then \
        curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
        echo "Types: deb" > /etc/apt/sources.list.d/docker.sources && \
        echo "URIs: https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu" >> /etc/apt/sources.list.d/docker.sources; \
    else \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
        echo "Types: deb" > /etc/apt/sources.list.d/docker.sources && \
        echo "URIs: https://download.docker.com/linux/ubuntu" >> /etc/apt/sources.list.d/docker.sources; \
    fi && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")" >> /etc/apt/sources.list.d/docker.sources && \
    echo "Components: stable" >> /etc/apt/sources.list.d/docker.sources && \
    echo "Signed-By: /etc/apt/keyrings/docker.asc" >> /etc/apt/sources.list.d/docker.sources && \
    # Skip Bazel apt repo in CN mirror mode (will use bazelisk instead)
    if [ "${EFFECTIVE_ARCH}" = "amd64" ] && [ "${USE_CN_MIRROR}" != "true" ]; then \
      curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /etc/apt/keyrings/bazel-archive-keyring.gpg && \
      echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" > /etc/apt/sources.list.d/bazel.list; \
    fi && \
    # Update package lists
    apt-get update --fix-missing

# Install packages and Chinese locale
RUN EFFECTIVE_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${EFFECTIVE_ARCH}" ]; then EFFECTIVE_ARCH="$(dpkg --print-architecture)"; fi && \
    PACKAGES="tree vim tmux python3-pip tldr patchelf \
docker-ce-cli docker-compose-plugin docker-buildx-plugin \
libjansson-dev libsnappy-dev libyaml-cpp-dev \
liblzma-dev libz-dev pkg-config libssl-dev graphviz \
locales" && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) EFFECTIVE_ARCH="amd64" ; if [ "${USE_CN_MIRROR}" != "true" ]; then PACKAGES="${PACKAGES} bazel"; fi ;; \
      amd64) if [ "${USE_CN_MIRROR}" != "true" ]; then PACKAGES="${PACKAGES} bazel"; fi ;; \
      arm64) ;; \
      *) echo "Unsupported target architecture: ${EFFECTIVE_ARCH}" >&2; exit 1 ;; \
    esac && \
    apt-get -y install --no-install-recommends ${PACKAGES} && \
    # Set python3 as default
    update-alternatives --install /usr/bin/python python /usr/bin/python3 100 && \
    # Generate Chinese locale
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8

# Install the latest stable Go by default while still allowing explicit pinning.
RUN RESOLVED_GO_VERSION="${GO_VERSION}" && \
    GO_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${GO_ARCH}" ]; then GO_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${GO_ARCH}" in \
      x86_64) GO_DOWNLOAD_ARCH="amd64" ;; \
      amd64) GO_DOWNLOAD_ARCH="amd64" ;; \
      arm64) GO_DOWNLOAD_ARCH="arm64" ;; \
      *) echo "Unsupported Go architecture: ${GO_ARCH}" >&2; exit 1 ;; \
    esac && \
    if [ -z "${RESOLVED_GO_VERSION}" ] || [ "${RESOLVED_GO_VERSION}" = "latest" ]; then \
      RESOLVED_GO_VERSION="$(python3 -c 'import json, urllib.request; releases = json.load(urllib.request.urlopen("https://go.dev/dl/?mode=json")); print(next(release["version"][2:] for release in releases if release.get("stable")))' )" && \
      test -n "${RESOLVED_GO_VERSION}"; \
    fi && \
    GO_TARBALL="go${RESOLVED_GO_VERSION}.linux-${GO_DOWNLOAD_ARCH}.tar.gz" && \
    GO_SHA256="$(python3 -c 'import json, sys, urllib.request; version = f"go{sys.argv[1]}"; filename = f"{version}.linux-{sys.argv[2]}.tar.gz"; releases = json.load(urllib.request.urlopen("https://go.dev/dl/?mode=json&include=all")); print(next(artifact["sha256"] for release in releases if release.get("version") == version for artifact in release.get("files", []) if artifact.get("filename") == filename))' "${RESOLVED_GO_VERSION}" "${GO_DOWNLOAD_ARCH}")" && \
    GO_ARCHIVE="/tmp/${GO_TARBALL}" && \
    echo "Installing Go ${RESOLVED_GO_VERSION} for ${GO_DOWNLOAD_ARCH}" && \
    if [ "${USE_CN_MIRROR}" = "true" ]; then \
        curl -fsSL --connect-timeout 20 --max-time 300 --retry 3 --retry-delay 2 \
          "https://mirrors.aliyun.com/golang/${GO_TARBALL}" \
          -o "${GO_ARCHIVE}" || \
        curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
          "https://go.dev/dl/${GO_TARBALL}" \
          -o "${GO_ARCHIVE}"; \
    else \
        curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
          "https://go.dev/dl/${GO_TARBALL}" \
          -o "${GO_ARCHIVE}"; \
    fi && \
    echo "${GO_SHA256}  ${GO_ARCHIVE}" | sha256sum -c - && \
    rm -rf "${GOROOT}" && \
    tar -C /usr/local -xzf "${GO_ARCHIVE}" && \
    rm -f "${GO_ARCHIVE}" && \
    go version

# Install nodejs and npm
RUN apt-get remove -y nodejs && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    if [ "${USE_CN_MIRROR}" = "true" ]; then \
        npm config set registry https://registry.npmmirror.com; \
    fi

# Install clangd-20
RUN apt-get install -y --no-install-recommends clangd-20 && \
    update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-20 100

# Install python packages (use Tsinghua PyPI mirror in CN mode for faster download)
RUN export DEBIAN_FRONTEND=noninteractive && \
    if [ "${USE_CN_MIRROR}" = "true" ]; then \
        pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
        pip3 config set global.trusted-host pypi.tuna.tsinghua.edu.cn; \
    fi && \
    pip3 install --upgrade pip && \
    pip3 install \
    numpy fabric2 psutil pandas toml distro \
    faker gprof2dot tzlocal matplotlib \
    ipykernel taos-ws-py taospy baostock tushare

# Install Bazelisk for ARM64 (always) and AMD64 (in CN mirror mode, since we skip apt bazel)
RUN EFFECTIVE_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${EFFECTIVE_ARCH}" ]; then EFFECTIVE_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) EFFECTIVE_ARCH="amd64" ;; \
      amd64|arm64) ;; \
      *) echo "Unsupported target architecture: ${EFFECTIVE_ARCH}" >&2; exit 1 ;; \
    esac && \
    if [ "${EFFECTIVE_ARCH}" = "arm64" ] || [ "${USE_CN_MIRROR}" = "true" ]; then \
      BAZELISK_ARCH="${EFFECTIVE_ARCH}" && \
      if [ "${USE_CN_MIRROR}" = "true" ]; then \
        curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 \
          "https://ghp.ci/https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${BAZELISK_ARCH}" \
          -o /usr/local/bin/bazel || \
        curl -fsSL \
          "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${BAZELISK_ARCH}" \
          -o /usr/local/bin/bazel; \
      else \
        curl -fsSL \
          "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${BAZELISK_ARCH}" \
          -o /usr/local/bin/bazel; \
      fi && \
      chmod +x /usr/local/bin/bazel; \
    fi

RUN apt-get -y install --no-install-recommends \
    autoconf libtool automake autotools-dev screen

# Install AI CLIs
RUN npm install -g opencode-ai @anthropic-ai/claude-code @openai/codex

# Install cc-switch-cli
RUN CC_SWITCH_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${CC_SWITCH_ARCH}" ]; then CC_SWITCH_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${CC_SWITCH_ARCH}" in \
      x86_64|amd64) CC_SWITCH_ARCHIVE="cc-switch-cli-linux-x64-musl.tar.gz" ;; \
      arm64) CC_SWITCH_ARCHIVE="cc-switch-cli-linux-arm64-musl.tar.gz" ;; \
      *) echo "Unsupported cc-switch architecture: ${CC_SWITCH_ARCH}" >&2; exit 1 ;; \
    esac && \
    CC_SWITCH_URL="https://github.com/saladday/cc-switch-cli/releases/latest/download/${CC_SWITCH_ARCHIVE}" && \
    CC_SWITCH_TARBALL="/tmp/${CC_SWITCH_ARCHIVE}" && \
    curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
      "${CC_SWITCH_URL}" \
      -o "${CC_SWITCH_TARBALL}" && \
    tar -xzf "${CC_SWITCH_TARBALL}" -C /tmp && \
    install -m 0755 /tmp/cc-switch /usr/local/bin/cc-switch && \
    rm -f "${CC_SWITCH_TARBALL}" /tmp/cc-switch && \
    cc-switch --version

# Configure Go modules proxy based on USE_CN_MIRROR
RUN if [ "${USE_CN_MIRROR}" = "true" ]; then \
        go env -w GOPROXY=https://goproxy.cn,direct; \
    fi && \
    go env -w GONOSUMDB=code.devops.xiaohongshu.com && \
    go env -w GOPRIVATE=code.devops.xiaohongshu.com

# Install uv via pip (pip already has CN mirror configured above), then use uv to install kimi-cli.
# UV_PYTHON_INSTALL_DIR must be world-readable so non-root users can execute the interpreter.
ENV UV_TOOL_DIR=/usr/local/share/uv-tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin
ENV UV_PYTHON_INSTALL_DIR=/usr/local/share/uv-python
RUN pip3 install uv && \
    uv tool install --python 3.13 kimi-cli && \
    chmod -R a+rx /usr/local/share/uv-tools /usr/local/share/uv-python && \
    kimi --version

# =============================================================================
# Stage 2: Final image with SSH and code-server
# This stage adds services that may change more frequently
# =============================================================================
FROM base AS devbox

ARG USE_CN_MIRROR=false
ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG TARGETARCH
ARG TARGETARCH_OVERRIDE
# Install SSH server and gosu (for clean user-switching in entrypoint)
RUN apt-get install -y --no-install-recommends openssh-server gosu && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'root:root' | chpasswd

# Install tmux.conf to a global path so both root and non-root users can symlink it
COPY devbox/tmux.conf /etc/tmux.conf
RUN sed -i 's/\r$//' /etc/tmux.conf

# Global prompt: git branch + newline before $
COPY devbox/scripts/devbox-prompt.sh /etc/profile.d/devbox-prompt.sh
RUN sed -i 's/\r$//' /etc/profile.d/devbox-prompt.sh && chmod 644 /etc/profile.d/devbox-prompt.sh

# Package startup script
COPY devbox/scripts/start-services.sh /usr/local/bin/start-services.sh
RUN sed -i 's/\r$//' /usr/local/bin/start-services.sh && chmod +x /usr/local/bin/start-services.sh

# Create non-root dev user if DEV_USER != root.
# docker group is NOT created here — the socket GID varies per host and is
# handled dynamically at container startup in setup_dev_user().
ARG DEV_USER=root
ARG DEV_HOME=/root
ARG DEV_UID=0
ARG DEV_GID=0
ARG DEV_GRANT_SUDO=false
RUN if [ "${DEV_USER}" != "root" ]; then \
      if [ -n "${DEV_GID}" ] && [ "${DEV_GID}" != "0" ]; then \
        groupadd --gid "${DEV_GID}" --non-unique "${DEV_USER}" 2>/dev/null || groupadd "${DEV_USER}" 2>/dev/null || true; \
      else \
        groupadd "${DEV_USER}" 2>/dev/null || true; \
      fi && \
      useradd_args="--home-dir ${DEV_HOME} --shell /bin/bash --create-home" && \
      if [ -n "${DEV_UID}" ] && [ "${DEV_UID}" != "0" ]; then \
        useradd_args="${useradd_args} --uid ${DEV_UID} --non-unique"; \
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

# Expose code-server port
EXPOSE 8080 22

# =============================================================================
# Stage 3: Xiaohongshu-focused development image
# This stage layers Ubuntu-compatible XHS development tools on top of devbox
# =============================================================================
FROM devbox AS devbox-red

ARG USE_CN_MIRROR=false
ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG TARGETARCH
ARG TARGETARCH_OVERRIDE

# Install system development libraries, upgrade GCC to 12, and install lld.
# lld is required because prebuilt XHS archives (libredraft, librocksdb) are non-PIC;
# gold rejects them when linking, and bfd lacks --start-lib support that Bazel relies on.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgoogle-perftools-dev libzstd-dev liblz4-dev libtbb-dev lld && \
    add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends gcc-12 g++-12 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100

# Install Bazel 7.4.1.
# The pre-downloaded cpython/bazel-skylib tarballs are omitted: they were only
# a build-time cache and Bazel fetches them automatically on first use anyway.
# The installer defaults to --prefix=/usr/local so bazel lands in /usr/local/bin,
# accessible to all users without any PATH changes.
RUN curl -fsSL --connect-timeout 20 --max-time 300 --retry 3 --retry-delay 2 \
    -o /tmp/bazel-7.4.1-installer-linux-x86_64.sh \
    "https://mirrors.huaweicloud.com/bazel/7.4.1/bazel-7.4.1-installer-linux-x86_64.sh" && \
    bash /tmp/bazel-7.4.1-installer-linux-x86_64.sh && \
    bazel --version && \
    rm -f /tmp/bazel-7.4.1-installer-linux-x86_64.sh

# Configure Bazel for XHS internal registry and remote cache.
# --linkopt=-fuse-ld=lld: use lld instead of gold; gold rejects R_X86_64_32 relocations
#   from prebuilt non-PIC archives (libredraft, librocksdb), and bfd lacks --start-lib.
# --linkopt=-no-pie: disable PIE so lld does not require all objects to be PIC;
#   correct for server binaries that link prebuilt non-PIC static archives.
RUN printf '\ncommon --enable_bzlmod\ncommon --registry=https://bazel-build.devops.xiaohongshu.com\nbuild --remote_cache=https://bazel-remote.devops.xiaohongshu.com\nbuild --cxxopt="-std=c++20"\nbuild --linkopt=-fuse-ld=lld\nbuild --linkopt=-no-pie\n' >> /etc/bazel.bazelrc

# Install protoc 4.25.2
RUN PROTOC_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${PROTOC_ARCH}" ]; then PROTOC_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${PROTOC_ARCH}" in \
      x86_64) PROTOC_ARCH="x86_64" ;; \
      amd64) PROTOC_ARCH="x86_64" ;; \
      arm64) PROTOC_ARCH="aarch_64" ;; \
      *) echo "Unsupported protoc architecture: ${PROTOC_ARCH}" >&2; exit 1 ;; \
    esac && \
    PROTOC_ZIP="protoc-25.2-linux-${PROTOC_ARCH}.zip" && \
    PROTOC_URL="https://github.com/protocolbuffers/protobuf/releases/download/v25.2/${PROTOC_ZIP}" && \
    curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
      "${PROTOC_URL}" -o "/tmp/${PROTOC_ZIP}" && \
    unzip -o "/tmp/${PROTOC_ZIP}" -d /usr/local && \
    rm -f "/tmp/${PROTOC_ZIP}" && \
    protoc --version

# Install codewiz proxy for transparent Claude Code and Codex access.
# A single proxy on port 8089 handles both Anthropic and OpenAI API formats.
# Skip if the respective API key is a real key; otherwise requires CODEWIZ_SESSION_TOKEN
# env var or ~/.local/share/codewiz/auth.json (persisted via /root volume).
COPY devbox/scripts/codewiz-proxy.py /usr/local/lib/codewiz-proxy.py
COPY devbox/scripts/codewiz_proxy/ /usr/local/lib/codewiz_proxy/
COPY devbox/scripts/start-claude-proxy.sh /usr/local/bin/start-claude-proxy.sh
COPY devbox/scripts/claude-proxy-wrapper.sh /usr/local/bin/claude-proxy-wrapper.sh
COPY devbox/scripts/codex-proxy-wrapper.sh /usr/local/bin/codex-proxy-wrapper.sh
COPY devbox/scripts/claude-use.sh /usr/local/bin/claude-use
RUN sed -i 's/\r$//' /usr/local/lib/codewiz-proxy.py \
    && sed -i 's/\r$//' /usr/local/bin/start-claude-proxy.sh \
    && sed -i 's/\r$//' /usr/local/bin/claude-proxy-wrapper.sh \
    && sed -i 's/\r$//' /usr/local/bin/codex-proxy-wrapper.sh \
    && sed -i 's/\r$//' /usr/local/bin/claude-use \
    && chmod +x /usr/local/bin/start-claude-proxy.sh \
    && chmod +x /usr/local/bin/claude-proxy-wrapper.sh \
    && chmod +x /usr/local/bin/codex-proxy-wrapper.sh \
    && chmod +x /usr/local/bin/claude-use \
    && CLAUDE_SYMLINK="$(which claude)" \
    && CLAUDE_REAL="$(readlink -f "$CLAUDE_SYMLINK")" \
    && ln -sf "$CLAUDE_REAL" /usr/local/bin/claude.real \
    && rm -f "$CLAUDE_SYMLINK" \
    && cp /usr/local/bin/claude-proxy-wrapper.sh "$CLAUDE_SYMLINK" \
    && chmod +x "$CLAUDE_SYMLINK" \
    && CODEX_SYMLINK="$(which codex)" \
    && CODEX_REAL="$(readlink -f "$CODEX_SYMLINK")" \
    && ln -sf "$CODEX_REAL" /usr/local/bin/codex.real \
    && rm -f "$CODEX_SYMLINK" \
    && cp /usr/local/bin/codex-proxy-wrapper.sh "$CODEX_SYMLINK" \
    && chmod +x "$CODEX_SYMLINK"

COPY devbox/config/cc-switch/providers-patch.sql /usr/local/share/cc-switch-providers.sql
