# docker build --no-cache -t hzcheng/devbox:latest -f ./devbox/Dockerfile ./devbox
# docker run -it --rm hzcheng/devbox:latest bash

# =============================================================================
# Stage 1: Base image with all development tools
# This stage contains all the heavy dependencies that rarely change
# =============================================================================
FROM mcr.microsoft.com/vscode/devcontainers/cpp:ubuntu-22.04 AS base

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
    printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" > /etc/apt/sources.list && \
    printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy-updates main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" >> /etc/apt/sources.list && \
    printf 'deb https://mirrors.tuna.tsinghua.edu.cn/%s/ jammy-backports main restricted universe multiverse\n' "${UBUNTU_MIRROR_ROOT}" >> /etc/apt/sources.list

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
    # Add LLVM apt repository
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    add-apt-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-20 main" && \
    # Add Node.js apt repository
    curl -fsSL https://deb.nodesource.com/setup_current.x | bash - && \
    # Add Docker apt repository
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "Types: deb" > /etc/apt/sources.list.d/docker.sources && \
    echo "URIs: https://download.docker.com/linux/ubuntu" >> /etc/apt/sources.list.d/docker.sources && \
    echo "Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")" >> /etc/apt/sources.list.d/docker.sources && \
    echo "Components: stable" >> /etc/apt/sources.list.d/docker.sources && \
    echo "Signed-By: /etc/apt/keyrings/docker.asc" >> /etc/apt/sources.list.d/docker.sources && \
    if [ "${EFFECTIVE_ARCH}" = "amd64" ]; then \
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
libjansson-dev libsnappy-dev \
liblzma-dev libz-dev pkg-config libssl-dev graphviz \
locales" && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) EFFECTIVE_ARCH="amd64" ; PACKAGES="${PACKAGES} bazel" ;; \
      amd64) PACKAGES="${PACKAGES} bazel" ;; \
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
    curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
      "https://go.dev/dl/${GO_TARBALL}" \
      -o "${GO_ARCHIVE}" && \
    echo "${GO_SHA256}  ${GO_ARCHIVE}" | sha256sum -c - && \
    rm -rf "${GOROOT}" && \
    tar -C /usr/local -xzf "${GO_ARCHIVE}" && \
    rm -f "${GO_ARCHIVE}" && \
    go version

# Install nodejs and npm
RUN apt-get remove -y nodejs && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install clangd-20
RUN apt-get install -y --no-install-recommends clangd-20 && \
    update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-20 100

# Install python packages
RUN export DEBIAN_FRONTEND=noninteractive && \
    pip3 install --upgrade pip && \
    pip3 install \
    numpy fabric2 psutil pandas toml distro \
    faker gprof2dot tzlocal matplotlib \
    ipykernel taos-ws-py taospy baostock tushare

# Install Bazelisk for ARM64 because Bazel's official apt repo is amd64-only.
RUN EFFECTIVE_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${EFFECTIVE_ARCH}" ]; then EFFECTIVE_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${EFFECTIVE_ARCH}" in \
      x86_64) ;; \
      amd64) ;; \
      arm64) curl -Lo /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-arm64 && \
        chmod +x /usr/local/bin/bazel ;; \
      *) echo "Unsupported target architecture: ${EFFECTIVE_ARCH}" >&2; exit 1 ;; \
    esac

RUN apt-get -y install --no-install-recommends \
    autoconf libtool automake autotools-dev screen

# Install AI CLIs
RUN npm install -g opencode-ai @anthropic-ai/claude-code @openai/codex

# Install kimi code
ENV PATH="/root/.local/bin:$PATH"
RUN curl -LsSf https://code.kimi.com/install.sh | bash

# =============================================================================
# Stage 2: Final image with SSH and code-server
# This stage adds services that may change more frequently
# =============================================================================
FROM base AS devbox

ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG TARGETARCH
ARG TARGETARCH_OVERRIDE
ARG CODE_SERVER_VERSION=latest
ARG CODE_SERVER_RELEASE_BASE_URL=https://github.com/coder/code-server/releases/download

# Install SSH server
RUN apt-get install -y --no-install-recommends openssh-server && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'root:root' | chpasswd

# Install the latest code-server by default while still allowing explicit pinning.
RUN apt-get update && \
    RESOLVED_CODE_SERVER_VERSION="${CODE_SERVER_VERSION}" && \
    CODE_SERVER_ARCH="${TARGETARCH_OVERRIDE:-${TARGETARCH}}" && \
    if [ -z "${CODE_SERVER_ARCH}" ]; then CODE_SERVER_ARCH="$(dpkg --print-architecture)"; fi && \
    case "${CODE_SERVER_ARCH}" in \
      x86_64) CODE_SERVER_ARCH="amd64" ;; \
      amd64|arm64) ;; \
      *) echo "Unsupported code-server architecture: ${CODE_SERVER_ARCH}" >&2; exit 1 ;; \
    esac && \
    if [ -z "${RESOLVED_CODE_SERVER_VERSION}" ] || [ "${RESOLVED_CODE_SERVER_VERSION}" = "latest" ]; then \
      LATEST_RELEASE_URL="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/coder/code-server/releases/latest)" && \
      RESOLVED_CODE_SERVER_VERSION="${LATEST_RELEASE_URL##*/}" && \
      RESOLVED_CODE_SERVER_VERSION="${RESOLVED_CODE_SERVER_VERSION#v}" && \
      test -n "${RESOLVED_CODE_SERVER_VERSION}"; \
    fi && \
    CODE_SERVER_DEB="/tmp/code-server_${RESOLVED_CODE_SERVER_VERSION}_${CODE_SERVER_ARCH}.deb" && \
    echo "Installing code-server v${RESOLVED_CODE_SERVER_VERSION}" && \
    curl -fsSL --connect-timeout 20 --max-time 300 --retry 5 --retry-delay 2 --retry-all-errors \
      "${CODE_SERVER_RELEASE_BASE_URL}/v${RESOLVED_CODE_SERVER_VERSION}/code-server_${RESOLVED_CODE_SERVER_VERSION}_${CODE_SERVER_ARCH}.deb" \
      -o "${CODE_SERVER_DEB}" && \
    dpkg -i "${CODE_SERVER_DEB}" && \
    rm -f "${CODE_SERVER_DEB}" && \
    # Verify installation
    which code-server && code-server --version

# Create code-server config directory
RUN mkdir -p /root/.config/code-server /usr/local/lib/devbox/codewiz-proxy

COPY ./tmux.conf /root/.tmux.conf
RUN sed -i 's/\r$//' /root/.tmux.conf

# Package startup script and vendored proxy
COPY ./codewiz-proxy/proxy.py /usr/local/lib/devbox/codewiz-proxy/proxy.py
COPY ./start-services.sh /usr/local/bin/start-services.sh
RUN sed -i 's/\r$//' /usr/local/bin/start-services.sh && chmod +x /usr/local/bin/start-services.sh && \
    sed -i 's/\r$//' /usr/local/lib/devbox/codewiz-proxy/proxy.py && chmod +x /usr/local/lib/devbox/codewiz-proxy/proxy.py

# Expose code-server port
EXPOSE 8080 22
