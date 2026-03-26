# DevBox Native CodeWiz Proxy Integration Design

## Context

DevBox already installs the Claude Code CLI inside the container and injects Anthropic-related environment variables through `devbox/docker-compose.yml`. Separately, `codewiz-proxy` provides a local reverse proxy that accepts Anthropic-compatible Claude Code requests, rewrites them for the internal CodeWiz adapter, and injects the required authentication headers.

Today the proxy is started manually outside the container, and users must explicitly run a wrapper command to point Claude Code at the local proxy. The goal of this change is to make the proxy a native DevBox capability so that a dev container can start with CodeWiz support already available.

## Goals

- Start `codewiz-proxy` automatically when the DevBox container starts.
- Keep the DevBox container usable even when CodeWiz credentials are not configured.
- Make `claude` inside the container use the local CodeWiz proxy by default when the proxy is enabled.
- Reuse the existing `codewiz-proxy` repository mounted under `/Projects` instead of copying proxy source into the DevBox repository.
- Keep the integration isolated to DevBox runtime configuration and startup logic.

## Non-Goals

- Running `codewiz-proxy` as a separate Docker Compose service.
- Bundling the proxy source code directly into the DevBox image.
- Forcing all DevBox users to configure CodeWiz credentials.
- Changing proxy request rewriting behavior or model mapping in `codewiz-proxy`.

## Proposed Approach

The integration will be implemented directly in `devbox/start-services.sh`.

At container startup, DevBox will perform the existing SSH, Git, and code-server setup. After those steps, the startup script will evaluate whether CodeWiz proxy support can be enabled. The proxy is considered enabled only when all of the following are true:

- `CODEWIZ_SESSION_TOKEN` is set
- `CODEWIZ_USER_EMAIL` is set
- the proxy entrypoint exists at the expected mounted path

When the prerequisites are met, DevBox will start `proxy.py` in the background inside the container and record its PID in a predictable runtime location. The proxy will continue listening on `127.0.0.1:${CODEWIZ_PROXY_PORT:-8088}` so it is only reachable from processes inside the container.

When prerequisites are missing, DevBox will log a clear informational message and continue startup without failing the container. In that case, DevBox will not rewrite Claude-related shell environment to point at the local proxy.

## Runtime Behavior

### Environment Variables

DevBox will pass the following variables from the root `.env` file into the container:

- `CODEWIZ_SESSION_TOKEN`
- `CODEWIZ_USER_EMAIL`
- `CODEWIZ_PROXY_PORT` with default `8088`
- `CODEWIZ_API_KEY` with the existing CodeWiz public key as the effective fallback
- `CODEWIZ_TARGET_URL` with the current adapter URL as the effective fallback

The example environment file will document that `CODEWIZ_SESSION_TOKEN` and `CODEWIZ_USER_EMAIL` are the only required values for enabling the proxy.

### Proxy Startup

The startup script will add a dedicated CodeWiz section with three responsibilities:

1. Resolve the mounted proxy location.
2. Validate whether CodeWiz proxy enablement prerequisites are satisfied.
3. Launch the proxy process in the background and log whether startup succeeded or was skipped.

The script will keep logs consistent with the rest of `start-services.sh` by using the existing logging helpers. Startup should be idempotent for a fresh container boot and avoid spawning duplicate proxy instances during one script execution.

### Claude Default Routing

When the proxy starts successfully, DevBox will make `claude` default to the local proxy by writing a dedicated shell snippet, preferably under `/etc/profile.d/`, that exports these values:

- `ANTHROPIC_BASE_URL=http://127.0.0.1:${CODEWIZ_PROXY_PORT}`
- `ANTHROPIC_API_KEY=${CODEWIZ_API_KEY:-same default value currently used by codewiz-proxy}`

This export will only be applied when CodeWiz proxy enablement succeeds. If credentials are absent or proxy startup is skipped, DevBox will leave `claude` untouched so any existing Anthropic configuration can continue to work.

The implementation should avoid destructive overwrites of unrelated shell profile content. The preferred mechanism is to write a small dedicated environment snippet that shell startup sources, rather than appending opaque blocks repeatedly to a profile file.

## Files To Change

- `devbox/docker-compose.yml`
  Pass CodeWiz-related environment variables into the container.
- `.example.env`
  Document the new CodeWiz variables and enablement rules.
- `devbox/start-services.sh`
  Add proxy prerequisite checks, proxy startup, runtime environment setup, and logging.

No changes are required in the `codewiz-proxy` repository for this integration design.

## Failure Handling

- Missing `CODEWIZ_SESSION_TOKEN`: log and skip proxy startup.
- Missing `CODEWIZ_USER_EMAIL`: log and skip proxy startup.
- Missing mounted proxy path: log and skip proxy startup.
- Proxy process exits immediately: log a warning and leave Claude defaults unchanged.
- Port already in use inside the container: log the conflict and leave Claude defaults unchanged.

These cases should never fail the container boot because the proxy is an optional DevBox capability.

## Testing Strategy

Configuration and shell validation:

- `docker compose config`
- `bash -n devbox/start-services.sh`

Runtime validation with credentials configured:

- `docker compose up -d --build`
- `docker compose ps`
- `docker compose exec devbox bash -lc 'ps -ef | grep proxy.py'`
- `docker compose exec devbox bash -lc 'printf "%s\n" "$ANTHROPIC_BASE_URL" "$ANTHROPIC_API_KEY"'`
- `docker compose exec devbox bash -lc 'curl -fsS http://127.0.0.1:${CODEWIZ_PROXY_PORT:-8088}'`

Runtime validation without credentials configured:

- `docker compose up -d --build`
- confirm container reaches healthy running state
- confirm startup logs indicate the proxy was skipped
- confirm `claude` is not forced to the local proxy environment

## Risks And Mitigations

- Shell environment drift
  Mitigation: use a dedicated sourced snippet instead of repeatedly mutating a general profile file.
- Hidden dependency on external repository layout
  Mitigation: check for the mounted proxy path explicitly and log the expected path when absent.
- Credentials expiring after container boot
  Mitigation: keep startup behavior simple and deterministic; expired credentials surface as proxy request failures rather than blocking container boot.
- Confusion between official Anthropic access and CodeWiz proxy mode
  Mitigation: only redirect `claude` when proxy enablement is confirmed.

## Open Decisions Resolved In This Design

- Integrate directly into `start-services.sh` instead of adding a second Compose service.
- Proxy remains optional and must not block container startup.
- `claude` inside the container defaults to CodeWiz when proxy startup succeeds.
- Proxy binds to loopback only and is not exposed as a host port by default.
