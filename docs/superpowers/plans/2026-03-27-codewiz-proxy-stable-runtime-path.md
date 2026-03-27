# CodeWiz Proxy Stable Runtime Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DevBox run the vendored CodeWiz proxy from a stable image-internal path so proxy startup no longer depends on bind-mounted `/Projects/DevBox`.

**Architecture:** Keep `devbox/codewiz-proxy/proxy.py` as the source-controlled vendored input, but change runtime execution to `/usr/local/lib/devbox/codewiz-proxy/proxy.py`, which is populated by Docker build-time `COPY` in both architecture-specific images. Preserve `CODEWIZ_PROXY_SCRIPT` as an override, then re-verify enabled, skipped, and override behavior using copy-only validation instead of relying on bind mounts for the proxy executable.

**Tech Stack:** Docker Compose, Bash, Dockerfiles, Python 3

---

## File Structure

- Modify: `devbox/start-services.sh`
  Change the default `CODEWIZ_PROXY_SCRIPT` path from `/Projects/DevBox/devbox/codewiz-proxy/proxy.py` to `/usr/local/lib/devbox/codewiz-proxy/proxy.py`.
- Modify: `devbox/Dockerfile.x86_64`
  Copy the vendored proxy script into `/usr/local/lib/devbox/codewiz-proxy/proxy.py` and ensure it is executable.
- Modify: `devbox/Dockerfile.arm64`
  Copy the vendored proxy script into `/usr/local/lib/devbox/codewiz-proxy/proxy.py` and ensure it is executable.
- Modify: none in tracked repo for verification
  Use disposable stacks and `docker cp` for override-path validation.

Do not touch unrelated user changes outside this worktree. Do not refactor `proxy.py`. Do not change the bind-mount model in `devbox/docker-compose.yml` as part of this fix.

### Task 1: Switch Runtime Default To The Image-Internal Proxy Path

**Files:**
- Modify: `devbox/start-services.sh`

- [ ] **Step 1: Confirm the current default still points at the bind-mounted repo path**

Run:

```bash
rg -n 'CODEWIZ_PROXY_SCRIPT=' devbox/start-services.sh
```

Expected:

- the default path is `/Projects/DevBox/devbox/codewiz-proxy/proxy.py`

- [ ] **Step 2: Update the default path to the stable image-internal location**

Change:

```bash
CODEWIZ_PROXY_SCRIPT="${CODEWIZ_PROXY_SCRIPT:-/Projects/DevBox/devbox/codewiz-proxy/proxy.py}"
```

to:

```bash
CODEWIZ_PROXY_SCRIPT="${CODEWIZ_PROXY_SCRIPT:-/usr/local/lib/devbox/codewiz-proxy/proxy.py}"
```

Leave the rest of the startup logic unchanged so explicit `CODEWIZ_PROXY_SCRIPT` overrides still win.

- [ ] **Step 3: Verify shell syntax after the path switch**

Run:

```bash
bash -n devbox/start-services.sh
```

Expected:

- no output
- exit status `0`

- [ ] **Step 4: Commit the runtime path correction**

Run:

```bash
git add devbox/start-services.sh
git commit -m "fix(devbox): use stable codewiz proxy runtime path"
```

Expected:

- commit contains only the startup-script path change

### Task 2: Package The Vendored Proxy Into The Stable Runtime Path

**Files:**
- Modify: `devbox/Dockerfile.x86_64`
- Modify: `devbox/Dockerfile.arm64`

- [ ] **Step 1: Confirm the Dockerfiles still package the proxy to the old `/Projects/DevBox` path**

Run:

```bash
rg -n '/Projects/DevBox/devbox/codewiz-proxy|/usr/local/lib/devbox/codewiz-proxy|proxy.py' \
  devbox/Dockerfile.x86_64 devbox/Dockerfile.arm64
```

Expected:

- both Dockerfiles reference `/Projects/DevBox/devbox/codewiz-proxy/proxy.py`
- neither Dockerfile yet references `/usr/local/lib/devbox/codewiz-proxy/proxy.py`

- [ ] **Step 2: Update both Dockerfiles to copy the proxy into the stable runtime path**

For both Dockerfiles, change the packaging block near the startup script so it follows this pattern:

```dockerfile
RUN mkdir -p /root/.config/code-server /usr/local/lib/devbox/codewiz-proxy

COPY ./codewiz-proxy/proxy.py /usr/local/lib/devbox/codewiz-proxy/proxy.py
COPY ./start-services.sh /usr/local/bin/start-services.sh

RUN sed -i 's/\r$//' /usr/local/bin/start-services.sh && chmod +x /usr/local/bin/start-services.sh && \
    sed -i 's/\r$//' /usr/local/lib/devbox/codewiz-proxy/proxy.py && chmod +x /usr/local/lib/devbox/codewiz-proxy/proxy.py
```

Do not change unrelated Dockerfile sections.

- [ ] **Step 3: Re-render Compose for both architectures**

Run:

```bash
PROJECT_NAME=devbox ARCH=x86_64 docker compose config >/tmp/codewiz-stable-x86.yml
PROJECT_NAME=devbox ARCH=arm64 docker compose config >/tmp/codewiz-stable-arm.yml
rg -n 'dockerfile:' /tmp/codewiz-stable-x86.yml /tmp/codewiz-stable-arm.yml
```

Expected:

- both `docker compose config` commands exit with status `0`
- the rendered files contain `dockerfile: Dockerfile.x86_64` and `dockerfile: Dockerfile.arm64` respectively

- [ ] **Step 4: Commit the Dockerfile runtime-path correction**

Run:

```bash
git add devbox/Dockerfile.x86_64 devbox/Dockerfile.arm64
git commit -m "fix(devbox): package codewiz proxy in stable path"
```

Expected:

- commit contains only the two Dockerfile changes

### Task 3: Verify Copy-Only Runtime Behavior

**Files:**
- Modify: none in the tracked repository

- [ ] **Step 1: Remove any leftover disposable verification containers**

Run:

```bash
PROJECT_NAME=DevBoxVendored docker compose down 2>/dev/null || true
PROJECT_NAME=DevBoxVendoredSkip docker compose down 2>/dev/null || true
PROJECT_NAME=DevBoxVendoredOverride docker compose down 2>/dev/null || true
docker ps -a --format '{{.Names}}' | grep '^DevBoxVendored' || true
```

Expected:

- no running `DevBoxVendored*` containers remain

- [ ] **Step 2: Prepare a disposable verification copy outside the active worktree**

Run:

```bash
rm -rf /tmp/DevBoxVendoredVerify
cp -a /Projects/DevBox/.worktrees/codewiz-proxy-vendored/. /tmp/DevBoxVendoredVerify/
git -C /tmp/DevBoxVendoredVerify status --short --branch
```

Expected:

- `/tmp/DevBoxVendoredVerify` exists
- it contains the current branch state

- [ ] **Step 3: Validate the enabled path uses the stable image-internal script**

Run from `/tmp/DevBoxVendoredVerify`:

```bash
PROJECT_NAME=DevBoxVendored \
CODE_SERVER_PORT=18090 \
SSH_PORT=12230 \
ARCH=arm64 \
CODEWIZ_SESSION_TOKEN=dummy-token \
CODEWIZ_USER_EMAIL=dummy@example.com \
docker compose up -d --build --force-recreate

PROJECT_NAME=DevBoxVendored docker compose ps
PROJECT_NAME=DevBoxVendored docker compose exec devbox bash -lc 'pgrep -af "/usr/local/lib/devbox/codewiz-proxy/proxy.py"'
PROJECT_NAME=DevBoxVendored docker compose exec devbox bash -lc 'printf "%s\n%s\n" "$ANTHROPIC_BASE_URL" "$ANTHROPIC_API_KEY"'
PROJECT_NAME=DevBoxVendored docker compose exec devbox bash -lc 'curl -fsS http://127.0.0.1:8088'
PROJECT_NAME=DevBoxVendored docker compose logs --tail=120 devbox
```

Expected:

- the container reaches `Up`
- the proxy process path is `/usr/local/lib/devbox/codewiz-proxy/proxy.py`
- the shell prints `http://127.0.0.1:8088`
- the shell prints a non-empty `ANTHROPIC_API_KEY`
- `curl` returns `{"status": "ok", "proxy": "codewiz"}`
- logs do not contain `CodeWiz proxy script not found`
- logs show `CodeWiz proxy: enabled`

- [ ] **Step 4: Validate the skipped path still behaves cleanly**

Run from `/tmp/DevBoxVendoredVerify`:

```bash
PROJECT_NAME=DevBoxVendoredSkip \
CODE_SERVER_PORT=18091 \
SSH_PORT=12231 \
ARCH=arm64 \
docker compose up -d --build --force-recreate

PROJECT_NAME=DevBoxVendoredSkip docker compose ps
PROJECT_NAME=DevBoxVendoredSkip docker compose logs --tail=120 devbox
PROJECT_NAME=DevBoxVendoredSkip docker compose exec devbox bash -lc 'test ! -f /etc/profile.d/devbox-codewiz.sh && echo missing'
PROJECT_NAME=DevBoxVendoredSkip docker compose exec devbox bash -lc 'ps -ef | grep "[p]roxy.py" || echo no-proxy'
```

Expected:

- the container reaches `Up`
- logs include a clear skip message
- logs show `CodeWiz proxy: skipped`
- the profile snippet is absent
- there is no proxy process

- [ ] **Step 5: Validate override support using container-local copy, not a bind mount**

From `/tmp/DevBoxVendoredVerify`, create the stopped container first, copy an alternate script into it, then start it:

```bash
PROJECT_NAME=DevBoxVendoredOverride \
CODE_SERVER_PORT=18092 \
SSH_PORT=12232 \
ARCH=arm64 \
CODEWIZ_SESSION_TOKEN=dummy-token \
CODEWIZ_USER_EMAIL=dummy@example.com \
CODEWIZ_PROXY_SCRIPT=/tmp/codewiz-proxy/proxy-override.py \
docker compose create

docker exec DevBoxVendoredOverride-devbox mkdir -p /tmp/codewiz-proxy
cp /tmp/DevBoxVendoredVerify/devbox/codewiz-proxy/proxy.py /tmp/DevBoxVendoredVerify/proxy-override.py
docker cp /tmp/DevBoxVendoredVerify/proxy-override.py DevBoxVendoredOverride-devbox:/tmp/codewiz-proxy/proxy-override.py
docker start DevBoxVendoredOverride-devbox

PROJECT_NAME=DevBoxVendoredOverride docker compose exec devbox bash -lc 'pgrep -af "/tmp/codewiz-proxy/proxy-override.py"'
```

Expected:

- the container starts successfully
- the proxy process path is `/tmp/codewiz-proxy/proxy-override.py`
- the override remains functional without relying on a bind-mounted repository path

- [ ] **Step 6: Clean up all disposable verification resources**

Run:

```bash
PROJECT_NAME=DevBoxVendored docker compose down
PROJECT_NAME=DevBoxVendoredSkip docker compose down
PROJECT_NAME=DevBoxVendoredOverride docker compose down
rm -f /tmp/DevBoxVendoredVerify/proxy-override.py
docker ps -a --format '{{.Names}}' | grep '^DevBoxVendored' || true
```

Expected:

- all disposable verification containers are removed
- the final `grep` prints nothing
