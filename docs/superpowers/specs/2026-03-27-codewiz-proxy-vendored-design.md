# DevBox Vendored CodeWiz Proxy Design

## Context

DevBox already supports native startup of the CodeWiz proxy flow through runtime configuration in `devbox/docker-compose.yml` and `devbox/start-services.sh`. However, the original integration expected the proxy implementation to exist outside the DevBox repository at `/Projects/Repos/codewiz-proxy/proxy.py`.

That external dependency is undesirable for a development container feature that is meant to work as a built-in DevBox capability. Users should not need to clone or mount a second repository just to get Claude Code traffic routed through the embedded CodeWiz proxy workflow.

Validation of the first vendoring attempt uncovered an additional constraint in this environment: DevBox itself runs inside a Docker development container, and host-to-container bind mounts can expose an incomplete or transformed view of the repository path. In practice, `/Projects/DevBox` cannot be treated as a stable runtime source for the proxy script. The runtime default must therefore point at a path populated by image build-time `COPY`, not at a path that only exists because the repository is bind-mounted into the running container.

## Goals

- Vendor the current `codewiz-proxy` Python implementation into the DevBox repository.
- Make DevBox use the vendored proxy implementation by default.
- Ensure the proxy is available in the built image even when `/Projects/Repos/codewiz-proxy` does not exist on the host.
- Ensure the runtime default does not depend on `/Projects/DevBox` or any other bind-mounted repository path.
- Preserve the existing `CODEWIZ_*` environment-variable interface and the startup behavior already implemented in DevBox.
- Keep the migration minimal: vendor first, avoid mixing the move with unrelated proxy refactors.

## Non-Goals

- Refactoring `proxy.py` behavior beyond what is required for vendoring.
- Replacing the Python implementation with another language or process manager.
- Introducing git submodules, runtime clones, or additional external repository dependencies.
- Changing the user-facing enable/disable semantics of the existing DevBox CodeWiz integration.
- Reworking DevBox's broader bind-mount model as part of this change.

## Proposed Approach

The `codewiz-proxy` implementation will be copied into the DevBox repository as a vendored runtime component. The canonical in-repo location will be:

- `devbox/codewiz-proxy/proxy.py`

The current implementation in `/Projects/Repos/codewiz-proxy/proxy.py` will be copied over with minimal changes. The goal is to preserve behavior while changing ownership and packaging.

DevBox startup will switch its default proxy path from the external repository location to a stable image-internal path populated during Docker build:

- `/usr/local/lib/devbox/codewiz-proxy/proxy.py`

The repository copy at `devbox/codewiz-proxy/proxy.py` remains the build input and source-controlled source of truth. Both architecture-specific Dockerfiles will `COPY` that vendored file into the image-internal runtime path.

The `CODEWIZ_PROXY_SCRIPT` environment variable will remain supported as an override, so advanced users can still point DevBox at a different script if they need to test a custom proxy variant. The only behavior change is the default path resolution when no override is provided.

## Repository Layout

### New Files

- `devbox/codewiz-proxy/proxy.py`
  Vendored Python proxy implementation copied from the existing external `codewiz-proxy` repository.

### Files To Modify

- `devbox/start-services.sh`
  Change the default `CODEWIZ_PROXY_SCRIPT` path from `/Projects/Repos/codewiz-proxy/proxy.py` to `/usr/local/lib/devbox/codewiz-proxy/proxy.py`.
- `devbox/Dockerfile.x86_64`
  Copy the vendored proxy script into `/usr/local/lib/devbox/codewiz-proxy/proxy.py`.
- `devbox/Dockerfile.arm64`
  Copy the vendored proxy script into `/usr/local/lib/devbox/codewiz-proxy/proxy.py`.

Optional documentation may be added later, but it is not required for this migration.

## Image And Runtime Behavior

### Default Script Path

The startup script will use this default path:

- `/usr/local/lib/devbox/codewiz-proxy/proxy.py`

This makes runtime startup independent of repository bind mounts and ensures the proxy script comes from a build-time copy under DevBox's control.

### Docker Image Packaging

Both architecture-specific Dockerfiles will copy the vendored `proxy.py` into the image so the file exists before runtime volume mounts or host-side repository structure are considered.

The image copy is not just a convenience. It is the runtime source of truth for the default path because the bind-mounted repository path cannot be relied upon in this docker-in-docker development setup.

Copying the proxy into the image is desirable because:

- it guarantees the proxy exists for image-based usage patterns
- it keeps the image self-contained
- it removes dependence on host-side bind-mount behavior for the default runtime path

### Runtime Override Compatibility

`CODEWIZ_PROXY_SCRIPT` will remain a supported override. This preserves flexibility for testing alternate proxy implementations while making the image-copied vendored version the default.

## Migration Strategy

This change should be implemented as a controlled vendor migration:

1. Copy the current external `proxy.py` into `devbox/codewiz-proxy/proxy.py`.
2. Change DevBox runtime defaults to use the image-internal copied path.
3. Ensure both Dockerfiles package the vendored script into that stable runtime path.
4. Verify that DevBox works without `/Projects/Repos/codewiz-proxy`.

The migration should not include opportunistic cleanup or behavioral edits to the proxy implementation. Future proxy changes can happen inside DevBox after the vendoring step is complete.

## Verification Strategy

Configuration and syntax validation:

- `PROJECT_NAME=<name> ARCH=<arch> docker compose config`
- `bash -n devbox/start-services.sh`

Vendored-path verification:

- start a temporary DevBox stack without depending on `/Projects/Repos/codewiz-proxy`
- confirm startup logs do not report a missing proxy script
- confirm the proxy starts from `/usr/local/lib/devbox/codewiz-proxy/proxy.py`
- confirm login shells still expose:
  - `ANTHROPIC_BASE_URL=http://127.0.0.1:<port>`
  - a non-empty `ANTHROPIC_API_KEY`
- confirm `curl http://127.0.0.1:<port>` returns the proxy health payload

Skipped-path verification:

- run without CodeWiz credentials
- confirm the container still starts
- confirm logs still show the skip path cleanly
- confirm no proxy process runs

Compatibility verification:

- optionally override `CODEWIZ_PROXY_SCRIPT` to a custom copied path inside the image or container filesystem and confirm the override still works

## Risks And Mitigations

- Drift between the vendored proxy and the old external repository
  Mitigation: make the vendored copy the new source of truth for DevBox and avoid maintaining dual live implementations for DevBox runtime.
- Hidden path assumptions in startup logic
  Mitigation: move the default to an image-internal path populated by build-time `COPY`, and keep the environment-variable override.
- Architecture-specific image packaging divergence
  Mitigation: apply the same vendored proxy copy behavior in both Dockerfiles.
- Migration mixed with refactoring
  Mitigation: keep the vendored copy minimal and behavior-preserving.
- Bind-mounted repository path behaves differently inside the docker dev container than on the host
  Mitigation: treat the bind-mounted repository as optional developer workspace input, not as the source of the default runtime executable.

## Decisions Confirmed

- Vendor the current proxy implementation into the DevBox repository.
- Use `devbox/codewiz-proxy/proxy.py` as the canonical in-repo location.
- Use `/usr/local/lib/devbox/codewiz-proxy/proxy.py` as the default runtime execution path.
- Keep `CODEWIZ_PROXY_SCRIPT` override support.
- Copy the vendored proxy into both architecture-specific images.
- Prefer a straight vendor migration over refactoring the proxy at the same time.
- The default runtime path must rely on image copy, not on bind-mounted `/Projects/DevBox`.
