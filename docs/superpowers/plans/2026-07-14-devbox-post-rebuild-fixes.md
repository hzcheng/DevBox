# DevBox Post-Rebuild Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the VS Code bridge reaper executable by the development user and avoid repeating the recursive home ownership repair after every container recreation.

**Architecture:** Install the reaper with an explicit `0755` mode at both repository and image boundaries. Store a UID/GID-keyed ownership marker inside the persistent development-home volume so container replacement preserves initialization state while identity changes still trigger one repair.

**Tech Stack:** Bash, Dockerfile, Docker Compose, shell integration tests

## Global Constraints

- Keep `shutdownAction: "none"` and the extension list unchanged.
- Keep the container running when the last VS Code window closes.
- Do not modify `devbox/config/cc-switch/providers-patch.sql` in this plan.
- Do not commit, push, or create a PR; leave all changes for user review.
- Do not recreate the running service without explicit approval because recreation disconnects VS Code.

---

### Task 1: Reaper file permissions

**Files:**
- Modify: `devbox/tests/test-vscode-bridge-reaper.sh`
- Modify: `devbox/scripts/vscode-bridge-reaper.sh` (file mode only)
- Modify: `devbox/Dockerfile`

**Interfaces:**
- Consumes: repository reaper at `devbox/scripts/vscode-bridge-reaper.sh`
- Produces: a source and image script readable/executable by non-root users with mode `0755`

- [ ] **Step 1: Write the failing permission assertions**

Add to `devbox/tests/test-vscode-bridge-reaper.sh`:

```bash
actual_mode=$(stat -c '%a' "${reaper}")
if [ "${actual_mode}" != 755 ]; then
    printf 'FAIL: expected reaper mode 755, got %s\n' "${actual_mode}" >&2
    exit 1
fi
assert_file_contains "${repo_root}/devbox/Dockerfile" \
    'chmod 0755 /usr/local/bin/vscode-bridge-reaper'
```

- [ ] **Step 2: Verify the red state**

Run: `bash devbox/tests/test-vscode-bridge-reaper.sh`

Expected: FAIL reporting repository mode `700` or missing explicit `chmod 0755`.

- [ ] **Step 3: Apply the minimal permission fix**

Run:

```bash
chmod 0755 devbox/scripts/vscode-bridge-reaper.sh
```

Change the Dockerfile install command to:

```dockerfile
RUN sed -i 's/\r$//' /usr/local/bin/vscode-bridge-reaper && chmod 0755 /usr/local/bin/vscode-bridge-reaper
```

- [ ] **Step 4: Verify the green state**

Run:

```bash
bash devbox/tests/test-vscode-bridge-reaper.sh
stat -c '%a %n' devbox/scripts/vscode-bridge-reaper.sh
```

Expected: test PASS and mode `755`.

---

### Task 2: Persistent development-home ownership marker

**Files:**
- Create: `devbox/tests/test-dev-home-ownership-marker.sh`
- Modify: `devbox/scripts/start-services.sh`

**Interfaces:**
- Consumes: `DEV_HOME`, `DEV_USER`, and numeric UID/GID returned by `id`
- Produces: `dev_home_ownership_marker UID GID`, returning `${DEV_HOME}/.cache/devbox/ownership-initialized-UID-GID`

- [ ] **Step 1: Write the failing marker test**

Create `devbox/tests/test-dev-home-ownership-marker.sh`. Source a copy of the real entrypoint with its final `main "$@"` invocation removed, then assert:

```bash
marker=$(dev_home_ownership_marker 1001 1001)
[ "${marker}" = "${DEV_HOME}/.cache/devbox/ownership-initialized-1001-1001" ]
mkdir -p "$(dirname "${marker}")"
touch "${marker}"
[ -f "$(dev_home_ownership_marker 1001 1001)" ]
[ ! -f "$(dev_home_ownership_marker 1002 1001)" ]
```

The test must exit with an explicit failure message for each assertion.

- [ ] **Step 2: Verify the red state**

Run: `bash devbox/tests/test-dev-home-ownership-marker.sh`

Expected: FAIL because `dev_home_ownership_marker` is undefined.

- [ ] **Step 3: Add the marker helper**

Add before `setup_dev_user`:

```bash
dev_home_ownership_marker() {
    local uid=$1
    local gid=$2
    printf '%s/.cache/devbox/ownership-initialized-%s-%s\n' \
        "${DEV_HOME}" "${uid}" "${gid}"
}
```

- [ ] **Step 4: Use the persistent marker in `setup_dev_user`**

Replace `/var/lib/devbox-initialized-${DEV_USER}` with:

```bash
local dev_uid dev_gid sentinel
dev_uid=$(id -u "${DEV_USER}")
dev_gid=$(id -g "${DEV_USER}")
sentinel=$(dev_home_ownership_marker "${dev_uid}" "${dev_gid}")
```

After the recursive `find ... chown` succeeds, create the marker with:

```bash
install -d -m 0755 -o "${DEV_USER}" -g "${DEV_USER}" "$(dirname "${sentinel}")"
touch "${sentinel}"
chown "${DEV_USER}:${DEV_USER}" "${sentinel}"
```

Keep the existing top-level `chown` behavior when the marker exists.

- [ ] **Step 5: Verify the green state**

Run:

```bash
bash devbox/tests/test-dev-home-ownership-marker.sh
bash -n devbox/scripts/start-services.sh
bash devbox/tests/test-vscode-bridge-reaper.sh
```

Expected: both tests PASS and syntax check exits 0.

---

### Task 3: Image and non-disruptive verification

**Files:**
- Verify only

**Interfaces:**
- Consumes: updated Docker image and current Compose configuration
- Produces: evidence that the image permissions and configuration are correct without recreating the running service

- [ ] **Step 1: Run repository verification**

Run:

```bash
bash devbox/tests/test-vscode-bridge-reaper.sh
bash devbox/tests/test-dev-home-ownership-marker.sh
bash -n devbox/scripts/vscode-bridge-reaper.sh devbox/scripts/start-services.sh
docker compose config >/tmp/devbox-compose-config.yaml
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Build the image**

Run: `docker compose build devbox`

Expected: exit 0; cached dependencies make only changed final layers rebuild.

- [ ] **Step 3: Verify image mode as the development user**

Run:

```bash
docker run --rm --user 1001:1001 \
  --entrypoint /usr/local/bin/vscode-bridge-reaper \
  home.teraai.cn/hzcheng/devbox:local-devbox-red --help
```

Expected: usage text and exit 0, with no permission error.

- [ ] **Step 4: Stop before service recreation**

Present the uncommitted diff and request approval before running:

```bash
docker compose up -d --force-recreate devbox
```

Expected: no runtime mutation until the user explicitly approves the disconnect.
