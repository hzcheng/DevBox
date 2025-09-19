# docker build --no-cache -t hzcheng/ubuntu:22.04.x86_64 -f ./docker/Dockerfile.ubuntu-22.04.x86_64 .
# docker run -it --rm hzcheng/ubuntu:22.04.x86_64 bash

# Base image
FROM mcr.microsoft.com/vscode/devcontainers/cpp:ubuntu-22.04

# Change source list
RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list 

# Install common dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get install -y software-properties-common wget curl gnupg lsb-release

# Add repositories
RUN \
    # Add LLVM apt repository
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    add-apt-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-20 main" && \
    # Add Node.js apt repository
    curl -fsSL https://deb.nodesource.com/setup_current.x | bash -

# Install packages
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -y install --no-install-recommends tree vim tmux python3-pip && \
    apt-get -y install --no-install-recommends libjansson-dev libsnappy-dev && \
    apt-get -y install --no-install-recommends liblzma-dev libz-dev pkg-config libssl-dev tldr graphviz &&\
    apt-get -y install --no-install-recommends inetutils-ping openssh-server golang openjdk-11-jdk docker.io &&\
    apt-get -y install --no-install-recommends docker-compose clangd-20 redis-tools mysql-client postgresql-client && \
    # Install Node.js
    apt-get remove -y nodejs && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    # Set clangd-20 as default
    update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-20 100 && \
    # Set python3 as default
    update-alternatives --install /usr/bin/python python /usr/bin/python3 100

# Install python packages
RUN export DEBIAN_FRONTEND=noninteractive && \
    pip3 install --upgrade pip && \
    pip3 install numpy fabric2 psutil pandas toml distro && \
    pip3 install faker gprof2dot tzlocal matplotlib ipykernel taos-ws-py taospy baostock tushare

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y patchelf