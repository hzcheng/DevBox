# DevBox Automatic Architecture Selection Design

## Context

DevBox currently requires users to set `ARCH` manually in the root `.env` file before running `docker compose build` or `docker compose up`. The current compose configuration uses that variable in two places:

- `devbox/docker-compose.yml` selects `Dockerfile.${ARCH}`
- `devbox/docker-compose.yml` tags the image with `${ARCH}`

That requirement is unnecessary friction for the default workflow because Docker already knows the target platform during build. The normal case should not require users to inspect their CPU architecture or edit `.env` just to start DevBox.

At the same time, DevBox still needs an explicit override path for advanced cases such as forcing an `arm64` or `amd64` build on a machine where the default target is not what the user wants.

## Goals

- Remove the need to manually set CPU architecture for the normal DevBox workflow.
- Make `docker compose build` and `docker compose up` work when `ARCH` is unset.
- Preserve manual architecture override support for advanced users.
- Keep the user-facing flow centered on standard `docker compose` commands rather than introducing a required wrapper script.
- Reduce architecture-specific duplication in the Docker build configuration where practical.

## Non-Goals

- Changing unrelated DevBox startup behavior.
- Reworking the container runtime model or volume layout.
- Adding a custom launcher CLI or replacing `docker compose` as the primary entrypoint.
- Supporting arbitrary architecture labels outside the Docker-native values used by BuildKit.

## Confirmed Decision

- Automatic architecture detection is the default behavior.
- Manual override remains supported.
- The override will use Docker-native architecture names: `amd64` and `arm64`.
- Existing manual `x86_64` examples in template docs will be replaced with `amd64` for consistency with Docker platform identifiers.

## Proposed Approach

DevBox will stop selecting between `Dockerfile.x86_64` and `Dockerfile.arm64` at the compose layer. Instead, it will build from a single `devbox/Dockerfile` and let Docker / BuildKit provide the target architecture through `TARGETARCH`.

The compose file will treat `ARCH` as an optional override:

- If `ARCH` is unset, compose will not set `platform`, so Docker uses the host-default target platform automatically.
- If `ARCH` is set to `amd64` or `arm64`, compose will set `platform: linux/${ARCH}` so the target platform is forced explicitly.

Inside the unified Dockerfile, architecture-specific package and repository decisions will branch on the effective architecture. The effective architecture will come from BuildKit's `TARGETARCH`, with optional validation against the override when one is supplied.

This keeps the default path automatic while preserving an explicit, Docker-native override path.

## Repository Layout

### New Files

- `devbox/Dockerfile`
  A unified Dockerfile that replaces the split architecture-specific Dockerfiles.

### Files To Modify

- `.example.env`
  Remove the required default `ARCH=x86_64` value and document `ARCH` as an optional override using `amd64` or `arm64`.
- `devbox/docker-compose.yml`
  Switch to the single Dockerfile, remove architecture-specific image naming, and make `platform` conditional on `ARCH` being set.
- `AGENTS.md`
  Update the build guidance so it no longer says the image is rebuilt for the `ARCH` set in `.env`.

### Files To Remove

- `devbox/Dockerfile.x86_64`
- `devbox/Dockerfile.arm64`

## Compose Behavior

The compose configuration will be changed to:

- always build from `devbox/Dockerfile`
- use a non-architecture-specific local image tag
- set `platform: linux/${ARCH}` only when `ARCH` is provided

That means the default workflow becomes:

```bash
cp .example.env .env
cp devbox/.example.env devbox/.env
docker compose build devbox
docker compose up -d
```

Users who need an explicit override can still run:

```bash
ARCH=arm64 docker compose build devbox
ARCH=amd64 docker compose up -d --build
```

## Dockerfile Behavior

The unified Dockerfile will keep the current package set and startup behavior but move architecture decisions into explicit branches.

The architecture-sensitive areas that need to be unified are:

- Ubuntu mirror configuration
  - `amd64` uses the standard `ubuntu` mirror path
  - `arm64` uses `ubuntu-ports`
- Bazel installation
  - `amd64` uses the Bazel apt repository
  - `arm64` installs Bazelisk directly
- code-server package download
  - download the `amd64` or `arm64` `.deb` that matches the target architecture

Where a step is already architecture-agnostic, it should stay shared.

## Validation And Error Handling

The Dockerfile should validate the effective architecture early and fail fast for unsupported values.

Supported architectures:

- `amd64`
- `arm64`

If `ARCH` is supplied with any other value, the build should stop with a clear error explaining that only `amd64` and `arm64` are supported for manual override.

If an architecture-dependent download or repository step is reached with an unsupported effective architecture, that step should also fail with a targeted error instead of silently choosing the wrong asset.

## Verification Strategy

Configuration verification:

- `docker compose config`
- `ARCH=arm64 docker compose config`
- `ARCH=amd64 docker compose config`

Expected results:

- all commands exit with status `0`
- the rendered compose config always points at `Dockerfile`
- when `ARCH` is unset, no manual architecture configuration is required
- when `ARCH` is set, the rendered config includes the matching `platform`

Build validation:

- `docker compose build devbox`

Expected result:

- the build resolves the correct target architecture without requiring `ARCH` in `.env`

Script validation:

- `bash -n devbox/start-services.sh`

Optional manual override validation:

- `ARCH=arm64 docker compose build devbox`
- `ARCH=amd64 docker compose build devbox`

These override builds are only expected to succeed where the local Docker environment supports the requested platform build.

## Risks And Mitigations

- The two Dockerfiles are not perfectly identical outside the obvious architecture differences.
  Mitigation: compare them carefully and preserve any intentional non-architecture behavior while merging.

- Existing users may still have `ARCH=x86_64` in a local `.env`.
  Mitigation: update the template comments and documentation to state that manual overrides now use `amd64` or `arm64`. The default path no longer requires any override.

- Cross-platform override support depends on the local Docker / BuildKit environment.
  Mitigation: preserve the override interface but document that successful cross-builds still depend on Docker's platform support on the host.

## Decisions Confirmed

- Do not require manual CPU architecture input for the standard DevBox flow.
- Keep the architecture override capability for advanced users.
- Standardize manual override values on `amd64` and `arm64`.
- Replace the split Dockerfile selection with one Dockerfile that branches internally using the target architecture.
