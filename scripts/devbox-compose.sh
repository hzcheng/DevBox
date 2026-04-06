#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_ENV_FILE="${PROJECT_ROOT}/.env"
OPENCLASH_ENV_FILE="${PROJECT_ROOT}/openclash/.env"

load_env_file() {
  local env_file="$1"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

load_env_file "${ROOT_ENV_FILE}"
load_env_file "${OPENCLASH_ENV_FILE}"

PROXY_PROVIDER="${PROXY_PROVIDER:-}"
if [[ -z "${PROXY_PROVIDER}" ]]; then
  if [[ -n "${BUILD_PROXY:-}" || -n "${RUNTIME_PROXY:-}" ]]; then
    PROXY_PROVIDER="external"
  else
    PROXY_PROVIDER="none"
  fi
fi

COMPOSE_PROFILES_VALUE="${COMPOSE_PROFILES:-}"
DEVBOX_BUILD_PROXY_VALUE="${BUILD_PROXY:-}"
DEVBOX_RUNTIME_PROXY_VALUE="${RUNTIME_PROXY:-}"

case "${PROXY_PROVIDER}" in
  none)
    DEVBOX_BUILD_PROXY_VALUE=""
    DEVBOX_RUNTIME_PROXY_VALUE=""
    ;;
  external)
    ;;
  openclash)
    COMPOSE_PROFILES_VALUE="${COMPOSE_PROFILES_VALUE:+${COMPOSE_PROFILES_VALUE},}openclash"
    : "${OPENCLASH_MIXED_PORT:?OPENCLASH_MIXED_PORT must be set in openclash/.env when PROXY_PROVIDER=openclash}"
    DEVBOX_BUILD_PROXY_VALUE="http://127.0.0.1:${OPENCLASH_MIXED_PORT}"
    DEVBOX_RUNTIME_PROXY_VALUE="http://host.docker.internal:${OPENCLASH_MIXED_PORT}"
    ;;
  *)
    echo "Unsupported PROXY_PROVIDER: ${PROXY_PROVIDER}" >&2
    echo "Expected one of: none, external, openclash" >&2
    exit 1
    ;;
esac

compose() {
  env \
    COMPOSE_PROFILES="${COMPOSE_PROFILES_VALUE}" \
    DEVBOX_BUILD_PROXY="${DEVBOX_BUILD_PROXY_VALUE}" \
    DEVBOX_RUNTIME_PROXY="${DEVBOX_RUNTIME_PROXY_VALUE}" \
    docker compose "$@"
}

if [[ "${PROXY_PROVIDER}" == "openclash" && "${1:-}" == "build" ]]; then
  compose build openclash
  compose up -d openclash

  if [[ "$#" -eq 1 ]]; then
    compose build devbox
    exit $?
  fi
fi

compose "$@"
