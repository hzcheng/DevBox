#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AGENT_NAME="${AGENT_NAME:-codex}"
SKILLS_CLI_PACKAGE="${SKILLS_CLI_PACKAGE:-skills}"
SUPERPOWERS_REPO="${SUPERPOWERS_REPO:-https://github.com/obra/superpowers}"
PLANNING_WITH_FILES_REPO="${PLANNING_WITH_FILES_REPO:-https://github.com/othmanadi/planning-with-files}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

install_skills() {
  local repo="$1"
  shift

  echo "Installing skills from ${repo} for agent ${AGENT_NAME}..."
  npx --yes "${SKILLS_CLI_PACKAGE}" add "${repo}" --agent "${AGENT_NAME}" -y "$@"
}

require_command npx

cd "${PROJECT_ROOT}"

install_skills "${SUPERPOWERS_REPO}" --skill '*' --full-depth
install_skills "${PLANNING_WITH_FILES_REPO}" --skill planning-with-files

echo
echo "Project preparation complete."
