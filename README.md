# DevBox

DevBox is a Docker-based development environment with an optional vendored OpenClash gateway.

This repository is the single entrypoint for:
- building and starting the `devbox` workspace container
- choosing whether proxying is disabled, uses an external proxy, or uses the vendored `openclash/` service
- managing the OpenClash runtime and dashboard when `PROXY_PROVIDER=openclash`

## Project Layout

- `docker-compose.yml`: root Compose entrypoint
- `scripts/devbox-compose.sh`: proxy-aware wrapper around `docker compose`
- `devbox/`: workspace container definition and code-server configuration
- `openclash/`: vendored Mihomo + metacubexd deployment
- `.example.env`: root configuration template
- `openclash/.example.env`: OpenClash-specific configuration template
- `AGENTS.md`: repository workflow notes

## Proxy Modes

Set `PROXY_PROVIDER` in the root `.env`:

- `none`: do not use a proxy and do not start OpenClash
- `external`: use the root `BUILD_PROXY` / `RUNTIME_PROXY` values
- `openclash`: start the vendored `openclash/` service and automatically route DevBox build/runtime traffic through it

When `PROXY_PROVIDER=openclash`:
- build traffic uses `http://127.0.0.1:${OPENCLASH_MIXED_PORT}`
- runtime traffic inside the container uses `http://host.docker.internal:${OPENCLASH_MIXED_PORT}`

## Configuration Files

### 1. Root `.env`

The root `.env` controls the overall project behavior.

Start from the template:

```bash
cp .example.env .env
```

Important keys:

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

Notes:
- `BUILD_PROXY` and `RUNTIME_PROXY` are used when `PROXY_PROVIDER=external`
- `PROXY_PROVIDER=openclash` ignores those explicit values and derives proxy addresses from `openclash/.env`

### 2. `openclash/.env`

This file controls the vendored OpenClash service itself.

Start from the template:

```bash
cp openclash/.example.env openclash/.env
```

Typical values:

```dotenv
OPENCLASH_SUBSCRIPTION_URL=https://example.com/subscription.yaml
OPENCLASH_MIXED_PORT=9981
OPENCLASH_CONTROLLER_PORT=9097
OPENCLASH_LOG_LEVEL=warning
OPENCLASH_UI_PATH=/openclash/
OPENCLASH_UI_DIR=/root/.config/mihomo/ui
OPENCLASH_STATE_DIR=/root/.config/mihomo
OPENCLASH_AUTO_UPDATE_UI=false
OPENCLASH_BUILD_MIHOMO_IMAGE=docker.io/metacubex/mihomo:latest
```

`openclash/.env` is only required when `PROXY_PROVIDER=openclash`.

## Quick Start

### No proxy

```bash
cd /Projects/DevBox
cp .example.env .env
cp devbox/.example.env devbox/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh up -d
```

Set in `.env`:

```dotenv
PROXY_PROVIDER=none
```

### External proxy

Set in `.env`:

```dotenv
PROXY_PROVIDER=external
BUILD_PROXY=http://your-build-proxy:port
RUNTIME_PROXY=http://your-runtime-proxy:port
```

Then run:

```bash
cd /Projects/DevBox
cp devbox/.example.env devbox/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh up -d
```

### Vendored OpenClash

Set root `.env`:

```dotenv
PROXY_PROVIDER=openclash
```

Set `openclash/.env`, then run:

```bash
cd /Projects/DevBox
cp .example.env .env
cp devbox/.example.env devbox/.env
cp openclash/.example.env openclash/.env
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh build
./scripts/devbox-compose.sh up -d
```

## Common Commands

Run everything from the repository root:

```bash
./scripts/devbox-compose.sh config
./scripts/devbox-compose.sh build
./scripts/devbox-compose.sh up -d
./scripts/devbox-compose.sh logs -f devbox
./scripts/devbox-compose.sh exec devbox bash
./scripts/devbox-compose.sh down
```

## DevBox Service

The `devbox` container provides the interactive development environment.

Exposed ports:
- code-server: `${CODE_SERVER_PORT:-8080}`
- SSH: `${SSH_PORT:-2222}`

Useful commands:

```bash
./scripts/devbox-compose.sh ps
./scripts/devbox-compose.sh logs -f devbox
./scripts/devbox-compose.sh exec devbox bash
```

## OpenClash Service

When `PROXY_PROVIDER=openclash`, the root wrapper enables the vendored `openclash` Compose profile.

The vendored OpenClash deployment includes:
- Mihomo mixed proxy service
- Mihomo controller API
- baked metacubexd web UI

It does not include a separate metrics stack such as Prometheus or Grafana.

See the detailed service guide at:
- `openclash/README.md`

## Verification

### Check merged configuration

```bash
./scripts/devbox-compose.sh config
```

### Check running services

```bash
./scripts/devbox-compose.sh ps
```

### Verify DevBox container access

```bash
./scripts/devbox-compose.sh exec devbox bash
```

### Verify OpenClash when enabled

From the host:

```bash
curl -sS -D - -o /tmp/openclash-ui.html http://127.0.0.1:${OPENCLASH_CONTROLLER_PORT}/ui/
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:${OPENCLASH_MIXED_PORT} || true
```

From the DevBox container:

```bash
./scripts/devbox-compose.sh exec devbox sh -lc 'env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY curl --noproxy "*" -sS -o /dev/null -w "%{http_code}\n" http://host.docker.internal:9981'
```

## Troubleshooting

- If `./scripts/devbox-compose.sh config` fails in OpenClash mode, check that `openclash/.env` exists and `OPENCLASH_MIXED_PORT` is set.
- If OpenClash starts but the dashboard cannot connect, check `openclash/README.md` and verify the UI path is `/openclash/`.
- If build-time proxying does not work in OpenClash mode, confirm the host can reach `127.0.0.1:${OPENCLASH_MIXED_PORT}`.
- If runtime proxying does not work in the container, confirm `host.docker.internal` resolves inside `devbox`.

## Notes

- Do not commit real secrets in `.env` files.
- The root wrapper preserves backward compatibility: if `PROXY_PROVIDER` is unset but `BUILD_PROXY` or `RUNTIME_PROXY` is set, the project behaves as `external` mode.
- For OpenClash-specific operations and troubleshooting, use `openclash/README.md` as the service-level reference.
