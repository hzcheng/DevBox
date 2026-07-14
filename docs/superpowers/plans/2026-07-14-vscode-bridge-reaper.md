# VS Code Bridge Reaper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periodically remove abandoned Dev Containers bridge processes while preserving bridges associated with live VS Code extension hosts.

**Architecture:** A Bash command scans `/proc`, correlates bridges and extension hosts through `REMOTE_CONTAINERS_IPC`, and terminates only old unreferenced bridges. The entrypoint starts one background loop. Tests use a synthetic proc tree and fake kill command.

**Tech Stack:** Bash 4+, Linux procfs, Docker Compose, shell integration tests

## Global Constraints

- Keep `shutdownAction: "none"` and the extension list unchanged.
- Defaults: scan every 600 seconds; require bridge age of 1,800 seconds.
- Missing or unreadable metadata always protects a process.
- Send `SIGTERM` only; never automatically use `SIGKILL`.
- Do not commit, push, or create a PR. Preserve all existing user changes.

---

### Task 1: Deterministic classification tests

**Files:**
- Create: `devbox/tests/test-vscode-bridge-reaper.sh`
- Test: `devbox/tests/test-vscode-bridge-reaper.sh`

**Interfaces:**
- Consumes: `devbox/scripts/vscode-bridge-reaper.sh --once [--dry-run]`
- Produces: synthetic proc fixtures and kill-call assertions

- [ ] **Step 1: Write the failing test**

Create a temporary proc tree with `uptime` and numeric process directories. Each process has NUL-separated `cmdline` and `environ` files plus a `stat` file whose field 22 is its start tick. A fake kill executable appends arguments to a log.

Fixture:

```text
PID 101: old bridge, IPC=/tmp/active.sock
PID 201: extension host, IPC=/tmp/active.sock
PID 102: old bridge, IPC=/tmp/stale.sock
PID 103: young bridge, IPC=/tmp/young.sock
PID 104: old bridge, missing REMOTE_CONTAINERS_IPC
```

Invoke:

```bash
VSCODE_BRIDGE_REAPER_PROC_ROOT="${proc_root}" \
VSCODE_BRIDGE_REAPER_KILL_BIN="${fake_kill}" \
VSCODE_BRIDGE_REAPER_CLOCK_TICKS=100 \
VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=100 \
"${reaper}" --once
```

Assert only PID 102 receives `-TERM`. Repeat with `--dry-run`: output reports one candidate but the kill log remains empty.

- [ ] **Step 2: Verify the red state**

Run `bash devbox/tests/test-vscode-bridge-reaper.sh`.

Expected: non-zero because the reaper does not exist.

- [ ] **Step 3: Verify test syntax**

Run `bash -n devbox/tests/test-vscode-bridge-reaper.sh`.

Expected: exit 0.

- [ ] **Step 4: Review checkpoint**

Leave the test uncommitted and inspect its diff.

---

### Task 2: Reaper implementation

**Files:**
- Create: `devbox/scripts/vscode-bridge-reaper.sh`
- Test: `devbox/tests/test-vscode-bridge-reaper.sh`

**Interfaces:**
- Consumes: interval, minimum-age, proc-root, kill-bin, and clock-tick environment overrides
- Produces: `--once`, `--dry-run`, summary logs, and targeted `SIGTERM`

- [ ] **Step 1: Parse arguments and defaults**

Support `--once`, `--dry-run`, and `--help`. Reject unknown flags and invalid numeric values.

```bash
INTERVAL_SECONDS="${VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS:-600}"
MIN_AGE_SECONDS="${VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS:-1800}"
PROC_ROOT="${VSCODE_BRIDGE_REAPER_PROC_ROOT:-/proc}"
KILL_BIN="${VSCODE_BRIDGE_REAPER_KILL_BIN:-kill}"
CLOCK_TICKS="${VSCODE_BRIDGE_REAPER_CLOCK_TICKS:-$(getconf CLK_TCK)}"
```

- [ ] **Step 2: Read process metadata**

Implement `read_cmdline PID`, `read_ipc_env PID`, and `read_process_age_seconds PID`. Compute age using field 22 of `stat`, clock ticks, and integer proc uptime.

- [ ] **Step 3: Collect active IPC values**

Implement `collect_active_ipcs`. Select command lines containing `--type=extensionHost`, read non-empty IPC values, and store them in associative array `ACTIVE_IPCS`.

- [ ] **Step 4: Classify fail closed**

A bridge must contain both `vscode-remote-containers-server-` and `.js`. Apply:

```text
unreadable cmdline/environment/age -> protect
matching active IPC               -> protect
age below threshold               -> protect
otherwise                         -> abandoned candidate
```

Normal mode calls `"${KILL_BIN}" -TERM "${pid}"`; dry-run only logs.

- [ ] **Step 5: Add the loop**

```bash
while true; do
    if ! scan_once; then
        log_warn "bridge scan failed; retrying after ${INTERVAL_SECONDS}s"
    fi
    sleep "${INTERVAL_SECONDS}"
done
```

In `--once` mode, scan once and exit. A failed scan must not end the entrypoint.

- [ ] **Step 6: Verify green state**

Run:

```bash
bash -n devbox/scripts/vscode-bridge-reaper.sh
bash devbox/tests/test-vscode-bridge-reaper.sh
VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=0 \
  devbox/scripts/vscode-bridge-reaper.sh --once --dry-run
```

Expected: syntax and tests pass; the real dry-run protects active bridges and sends no signal.

- [ ] **Step 7: Review checkpoint**

Run `git diff --check`; leave script and test uncommitted.

---

### Task 3: Startup integration

**Files:**
- Modify: `devbox/Dockerfile`
- Modify: `devbox/docker-compose.yml`
- Modify: `devbox/scripts/start-services.sh`

**Interfaces:**
- Consumes: installed `/usr/local/bin/vscode-bridge-reaper` and service settings
- Produces: one background reaper loop owned by the development user

- [ ] **Step 1: Install the script**

```dockerfile
COPY devbox/scripts/vscode-bridge-reaper.sh /usr/local/bin/vscode-bridge-reaper
RUN sed -i 's/\\r$//' /usr/local/bin/vscode-bridge-reaper && \
    chmod +x /usr/local/bin/vscode-bridge-reaper
```

- [ ] **Step 2: Add Compose defaults**

```yaml
- VSCODE_BRIDGE_REAPER_ENABLED=${VSCODE_BRIDGE_REAPER_ENABLED:-true}
- VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS=${VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS:-600}
- VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=${VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS:-1800}
```

- [ ] **Step 3: Start the service**

Add `setup_vscode_bridge_reaper` to the entrypoint. When enabled, validate the executable, log settings, and launch once in the background. Use `gosu` for a non-root dev user. Missing executable logs a warning. Call after user setup and before SSH; keep final `wait`.

- [ ] **Step 4: Verify integration**

```bash
bash -n devbox/scripts/start-services.sh
bash -n devbox/scripts/vscode-bridge-reaper.sh
docker compose config >/tmp/devbox-compose-config.yaml
grep -q 'VSCODE_BRIDGE_REAPER_ENABLED: "true"' /tmp/devbox-compose-config.yaml
bash devbox/tests/test-vscode-bridge-reaper.sh
```

Expected: all exit 0.

- [ ] **Step 5: Review checkpoint**

Present the uncommitted implementation diff; do not commit.

---

### Task 4: Build and runtime verification

**Files:**
- Verify only

**Interfaces:**
- Consumes: Task 3 image and service configuration
- Produces: evidence that active bridges survive, abandoned bridges are reaped, and the container remains running

- [ ] **Step 1: Capture baseline**

Run `docker stats --no-stream devbox-devbox` and `pgrep -af 'vscode-remote-containers-server-' || true`.

- [ ] **Step 2: Build**

Run `docker compose build devbox`.

Expected: exit 0 and the image contains the reaper.

- [ ] **Step 3: Stop before recreation**

Obtain explicit approval because this disconnects VS Code, then run:

```bash
docker compose up -d --force-recreate devbox
```

- [ ] **Step 4: Verify after reconnect**

```bash
docker compose ps devbox
docker exec devbox-devbox pgrep -af 'vscode-bridge-reaper'
docker exec devbox-devbox /usr/local/bin/vscode-bridge-reaper --once --dry-run
```

Expected: container running, exactly one daemon reaper, active bridge protected.

- [ ] **Step 5: Validate cleanup**

Temporarily shorten interval and age, perform attach/detach cycles, and verify abandoned bridges return to the active-session baseline. Restore 600/1,800 defaults.

- [ ] **Step 6: Final verification**

```bash
bash devbox/tests/test-vscode-bridge-reaper.sh
bash -n devbox/scripts/vscode-bridge-reaper.sh
bash -n devbox/scripts/start-services.sh
docker compose config >/dev/null
git diff --check
git status --short
```

Expected: all verification commands exit 0. Present uncommitted changes and measurements for user review.

- [ ] **Step 7: Verify rollback control**

Run `VSCODE_BRIDGE_REAPER_ENABLED=false docker compose config` and verify the
rendered service environment disables the reaper. Do not recreate the running
service during this check.
