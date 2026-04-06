# DevBox 使用说明

DevBox 是一个基于 Docker Compose 的开发环境仓库，并内置了可选的 OpenClash 子项目。

当前仓库是统一入口，用来：
- 构建并启动 `devbox` 开发容器
- 控制是否启用代理
- 选择使用外部代理，或使用仓库内置的 `openclash/`
- 在启用 OpenClash 时统一管理代理服务和面板

## 目录结构

- `docker-compose.yml`：根 Compose 入口
- `scripts/devbox-compose.sh`：带代理模式处理的统一启动脚本
- `devbox/`：开发容器定义、code-server 配置等
- `openclash/`：仓库内置的 Mihomo + metacubexd 部署
- `.example.env`：根配置模板
- `openclash/.example.env`：OpenClash 专用配置模板
- `AGENTS.md`：仓库协作与操作说明
- `README.md`：英文说明
- `README.zh-CN.md`：中文说明

## 代理模式

在根目录 `.env` 中通过 `PROXY_PROVIDER` 控制代理行为：

- `none`：不使用代理，也不启动 OpenClash
- `external`：使用根 `.env` 里显式配置的 `BUILD_PROXY` / `RUNTIME_PROXY`
- `openclash`：启动仓库内置的 `openclash/`，并让 DevBox 自动走它提供的代理

当 `PROXY_PROVIDER=openclash` 时：
- 构建阶段走 `http://127.0.0.1:${OPENCLASH_MIXED_PORT}`
- 容器运行时走 `http://host.docker.internal:${OPENCLASH_MIXED_PORT}`

## 配置文件

### 1）根目录 `.env`

根 `.env` 负责整个项目的公共行为控制。

先复制模板：

```bash
cp .example.env .env
```

常用配置示例：

```dotenv
PROJECT_NAME=DevBox
PROXY_PROVIDER=none
USE_CN_MIRROR=false
BUILD_PROXY=
RUNTIME_PROXY=
NO_PROXY=
CODE_SERVER_PORT=8080
SSH_PORT=2222
```

说明：
- 当 `PROXY_PROVIDER=external` 时，使用 `BUILD_PROXY` 和 `RUNTIME_PROXY`
- 当 `PROXY_PROVIDER=openclash` 时，这两个值会被自动派生覆盖，不需要手工填写 OpenClash 地址

### 2）`openclash/.env`

`openclash/.env` 只负责 OpenClash 子项目自身配置。

先复制模板：

```bash
cp openclash/.example.env openclash/.env
```

常用配置示例：

```dotenv
OPENCLASH_SUBSCRIPTION_URL=https://example.com/subscription.yaml
OPENCLASH_MIXED_PORT=9981
OPENCLASH_CONTROLLER_PORT=9097
OPENCLASH_LOG_LEVEL=warning
OPENCLASH_UI_PATH=/openclash/
OPENCLASH_UI_DIR=/root/.config/mihomo/ui
OPENCLASH_STATE_DIR=/root/.config/mihomo
OPENCLASH_AUTO_UPDATE_UI=false
```

只有在 `PROXY_PROVIDER=openclash` 时，才需要这个文件。

## 快速开始

所有命令都在仓库根目录执行。

### 不启用代理

根 `.env` 设置：

```dotenv
PROXY_PROVIDER=none
```

执行：

```bash
cd /Projects/DevBox
cp .example.env .env
cp devbox/.example.env devbox/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh up -d
```

### 使用外部代理

根 `.env` 设置：

```dotenv
PROXY_PROVIDER=external
BUILD_PROXY=http://your-build-proxy:port
RUNTIME_PROXY=http://your-runtime-proxy:port
```

执行：

```bash
cd /Projects/DevBox
cp .example.env .env
cp devbox/.example.env devbox/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh up -d
```

### 使用仓库内置 OpenClash

根 `.env` 设置：

```dotenv
PROXY_PROVIDER=openclash
```

然后准备 OpenClash 配置并启动：

```bash
cd /Projects/DevBox
cp .example.env .env
cp devbox/.example.env devbox/.env
cp openclash/.example.env openclash/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh build
./scripts/devbox-compose.sh up -d
```

## 常用命令

```bash
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh build
./scripts/devbox-compose.sh up -d
./scripts/devbox-compose.sh logs -f devbox
./scripts/devbox-compose.sh exec devbox bash
./scripts/devbox-compose.sh down
```

## DevBox 容器

`devbox` 是实际的开发工作容器。

默认暴露端口：
- code-server：`${CODE_SERVER_PORT:-8080}`
- SSH：`${SSH_PORT:-2222}`

常用命令：

```bash
./scripts/devbox-compose.sh ps
./scripts/devbox-compose.sh logs -f devbox
./scripts/devbox-compose.sh exec devbox bash
```

## OpenClash 子项目

当 `PROXY_PROVIDER=openclash` 时，根启动脚本会自动启用 `openclash` 的 Compose profile。

当前内置 OpenClash 包含：
- Mihomo mixed proxy 服务
- Mihomo controller API
- 内置的 metacubexd Web UI

当前**不包含**独立监控栈，例如：
- Prometheus
- Grafana
- 独立 metrics exporter

更详细的 OpenClash 使用和排障，请看：
- `openclash/README.md`

## 验证

### 检查合并后的 Compose 配置

```bash
./scripts/devbox-compose.sh config
```

### 检查容器状态

```bash
./scripts/devbox-compose.sh ps
```

### 进入 DevBox 容器

```bash
./scripts/devbox-compose.sh exec devbox bash
```

### OpenClash 启用后的基础验证

宿主机执行：

```bash
curl -sS -D - -o /tmp/openclash-ui.html http://127.0.0.1:${OPENCLASH_CONTROLLER_PORT}/ui/
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:${OPENCLASH_MIXED_PORT} || true
```

容器内执行：

```bash
./scripts/devbox-compose.sh exec devbox sh -lc 'env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY curl --noproxy "*" -sS -o /dev/null -w "%{http_code}\n" http://host.docker.internal:9981'
```

## 常见问题

- 如果 `./scripts/devbox-compose.sh config` 在 OpenClash 模式下失败，先检查 `openclash/.env` 是否存在，以及 `OPENCLASH_MIXED_PORT` 是否已设置。
- 如果 OpenClash 面板能打开但无法连接后端，优先检查 `openclash/README.md` 中的 UI 路径配置。
- 如果 OpenClash 模式下构建代理不生效，先确认宿主机能访问 `127.0.0.1:${OPENCLASH_MIXED_PORT}`。
- 如果容器内运行时代理不生效，检查 `host.docker.internal` 在 `devbox` 容器内是否可解析。

## 说明

- 不要把真实密钥或订阅地址提交到仓库。
- 根启动脚本保留了兼容逻辑：如果未设置 `PROXY_PROVIDER`，但设置了 `BUILD_PROXY` 或 `RUNTIME_PROXY`，则默认按 `external` 模式处理。
- OpenClash 细节操作与排障，以 `openclash/README.md` 为准。
