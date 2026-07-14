# VS Code Dev Containers Bridge Reaper Design

## Context

The long-running `devbox-devbox` container accumulated 1,451
`vscode-remote-containers-server-*.js` bridge processes over five weeks. The
bridges consumed most of the container's memory and process budget, which made
later attach attempts slow and unreliable. A one-time cleanup reduced container
memory from 31.66 GiB to 7.93 GiB and reduced the bridge count from 1,451 to 1.

The container must remain running when VS Code closes. Therefore
`shutdownAction: "none"` remains unchanged. The fix will prevent abandoned
bridges from accumulating without stopping the container or changing the set of
installed extensions.

## Goals

- Periodically remove abandoned Dev Containers bridge processes.
- Never terminate a bridge that belongs to a live VS Code extension host.
- Keep the DevBox container and unrelated development processes running.
- Make cleanup decisions observable and testable before enabling termination.

## Non-goals

- Stopping or recreating the DevBox container.
- Changing VS Code's `shutdownAction` or extension list.
- Killing VS Code Server, extension-host, terminal, build, tmux, or application
  processes.
- Treating workspace lock files as the primary performance problem.

## Design

### Reaper command

Add `devbox/scripts/vscode-bridge-reaper.sh`. It supports a single scan and a
daemon loop:

- `--once` performs one scan and exits.
- `--dry-run` logs candidates without sending signals.
- The default mode scans immediately and then repeats every 600 seconds.

The scan interval and minimum bridge age are configurable through
`VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS` and
`VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS`. Defaults are 600 seconds and 1,800
seconds respectively.

### Active-session detection

Each Dev Containers bridge and its corresponding extension host share a unique
`REMOTE_CONTAINERS_IPC` environment value. For each scan, the reaper will:

1. Enumerate processes whose command line contains both
   `vscode-remote-containers-server-` and `.js`.
2. Read the bridge's `REMOTE_CONTAINERS_IPC` value from `/proc/<pid>/environ`.
3. Enumerate live VS Code extension-host processes and collect their
   `REMOTE_CONTAINERS_IPC` values.
4. Protect a bridge whenever its IPC value appears in the active extension-host
   set.
5. Protect bridges younger than the configured minimum age.
6. Mark only old, unreferenced bridges as abandoned.

If a process environment cannot be read, the reaper fails closed and protects
that process. An empty or missing IPC value is never sufficient by itself to
terminate a bridge.

### Termination

For each abandoned bridge, the reaper sends `SIGTERM` and logs the PID, age, and
IPC identifier. It does not escalate to `SIGKILL` automatically. The bridge's
waiting shell should exit when the child terminates; unrelated processes are not
matched.

### Service integration

`devbox/scripts/start-services.sh` will start one background reaper loop during
container startup and leave the existing final `wait` in place. The reaper will
run under the configured development user when possible so it has the same
permissions as VS Code processes. Startup logs will state whether the reaper is
enabled and show its interval and age threshold.

The feature is enabled by default and can be disabled with
`VSCODE_BRIDGE_REAPER_ENABLED=false` in Compose environment configuration.

The installed script must be owned by root with mode `0755`. Bash needs read
permission as well as execute permission for a script, so a symbolic
`chmod +x` is not sufficient when the source file was created with a restrictive
mode. The repository copy will also use mode `0755` so local tests exercise the
same access model as the image.

### Persistent ownership initialization

The development home directory is a persistent volume, while `/var/lib` belongs
to the replaceable container filesystem. The first-start ownership marker will
therefore live under `${DEV_HOME}/.cache/devbox/` and include the development
user's numeric UID and GID. After a successful recursive ownership repair, the
entrypoint creates that marker.

On later container recreations with the same persistent home volume and the
same UID/GID, the marker remains and the entrypoint only verifies the home
directory itself instead of recursively traversing it. A new volume or a UID/GID
change produces a different or missing marker and intentionally triggers one
new recursive repair.

## Logging and failure behavior

Each scan logs these counters: bridges examined, active bridges protected,
young bridges protected, unreadable bridges protected, and abandoned bridges
terminated. A scan failure is logged as a warning and the loop continues on the
next interval. The reaper must never cause the container entrypoint to exit.

## Testing

Shell tests will cover:

- A bridge with a matching live extension-host IPC value is protected.
- An old bridge without a matching extension-host IPC value is selected.
- A young unreferenced bridge is protected.
- A bridge with unreadable or missing environment metadata is protected.
- `--dry-run` reports a candidate but does not terminate it.
- `--once` completes without leaving a background loop.
- The repository and image copies of the reaper are readable and executable by
  the development user (`0755`).
- The ownership marker survives container recreation because it is stored in
  the persistent home volume.
- The marker is keyed by UID/GID, so a changed identity triggers reinitialization.

Static verification will include `bash -n` for the reaper and entrypoint, plus
`docker compose config` for the Compose changes.

Runtime verification will record bridge count and container PID/memory usage,
perform attach and detach cycles, wait beyond the configured test interval, and
verify that abandoned bridges return to the baseline while active windows remain
connected. The DevBox container must remain in the running state throughout.

## Rollback

Set `VSCODE_BRIDGE_REAPER_ENABLED=false` and recreate the Compose service, or
revert the reaper integration commit. No VS Code data or workspace files are
modified, so rollback requires no data migration.
