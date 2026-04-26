#!/usr/bin/env bash
# Generate devbox/.devcontainer.json from .env
# Run this after changing DEV_USER or DEV_HOME in .env.
# The generated file is .gitignored — only the template (.devcontainer.json) is tracked.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${DEVBOX_DIR}/.." && pwd)"

ENV_FILE="${REPO_ROOT}/.env"
TEMPLATE="${DEVBOX_DIR}/.devcontainer.json.tpl"
OUTPUT="${DEVBOX_DIR}/.devcontainer.json"

if [ ! -f "${ENV_FILE}" ]; then
    echo "Error: ${ENV_FILE} not found. Copy .env.example or create .env first." >&2
    exit 1
fi

# Source .env in a subshell to pick up DEV_USER and DEV_HOME without polluting this shell.
# set -a exports every variable defined in the sourced file automatically.
eval "$(set -a; . "${ENV_FILE}"; set +a; printf 'DEV_USER=%q\nDEV_HOME=%q\n' "${DEV_USER:-root}" "${DEV_HOME:-/root}")"

WORKSPACE_FOLDER="${DEV_HOME}/projects/DevBox"
REMOTE_USER="${DEV_USER}"

sed \
    -e "s|\"workspaceFolder\": \".*\"|\"workspaceFolder\": \"${WORKSPACE_FOLDER}\"|" \
    -e "s|\"remoteUser\": \".*\"|\"remoteUser\": \"${REMOTE_USER}\"|" \
    "${TEMPLATE}" > "${OUTPUT}"

echo "Generated ${OUTPUT}"
echo "  workspaceFolder: ${WORKSPACE_FOLDER}"
echo "  remoteUser:      ${REMOTE_USER}"
