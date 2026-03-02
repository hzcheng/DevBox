# Repository Guidelines

## Project Structure & Module Organization
The repository is a Docker-based development environment, not an application codebase. Use these paths as the source of truth:
- `docker-compose.yml`: root entrypoint; includes `devbox/docker-compose.yml`.
- `devbox/`: container definitions and runtime scripts (`Dockerfile.x86_64`, `Dockerfile.arm64`, `start-services.sh`, `.devcontainer.json`, `tmux.conf`).
- `devbox/config/code-server/User/`: shared code-server settings, keybindings, and project manager config.
- `.example.env` and `devbox/.example.env`: template configuration for local `.env` files.

## Build, Test, and Development Commands
Run commands from repository root:

```bash
cp .example.env .env && cp devbox/.example.env devbox/.env
docker compose config
docker compose build devbox
docker compose up -d
docker compose logs -f devbox
docker compose exec devbox bash
docker compose down
```

- `docker compose config` validates merged Compose files before runtime changes.
- `build` rebuilds the image for the `ARCH` set in `.env`.
- `up -d` starts SSH and code-server via `start-services.sh`.

## Coding Style & Naming Conventions
- YAML files use 2-space indentation; keep keys grouped by function (build, volumes, env, ports).
- JSON files in this repo use 4-space indentation (match `.devcontainer.json` and `.vscode/settings.json`).
- Shell scripts target Bash, stay executable, and use descriptive kebab-case names (example: `start-services.sh`).
- Environment variables are uppercase with underscores (`CODE_SERVER_PORT`, `SSH_PUBLIC_KEY`).

## Testing Guidelines
There is no automated unit test suite yet. For every config/runtime change:

```bash
docker compose config
bash -n devbox/start-services.sh
docker compose up -d --build
```

Then verify service health (`docker compose ps`) and confirm code-server/SSH ports from `.env` are reachable.

## Commit & Pull Request Guidelines
Recent history follows Conventional Commit style (for example, `feat(devbox): ...`, `feat(code-server): ...`). Prefer:
- `<type>(<scope>): <imperative summary>`
- small, focused commits by file/functionality

PRs should include:
- concise change summary and rationale
- any new/changed `.env` keys
- exact verification commands run and results
- screenshots only when editor/UI behavior changes

## Security & Configuration Tips
- Do not commit real secrets in `.env`; update `.example.env` instead.
- Prefer `SSH_PUBLIC_KEY` over password-only SSH access.
- Treat Docker socket mounting (`/var/run/docker.sock`) as privileged access.
