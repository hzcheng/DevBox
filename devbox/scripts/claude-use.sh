#!/usr/bin/env bash
# claude-use — switch or inspect the claude proxy provider at runtime.
# No container restart needed.
#
# Usage:
#   claude-use <provider>    Switch to the given provider (codewiz | openclaw)
#   claude-use status        Show the current provider and proxy status
#   claude-use -h            Show this help message
set -euo pipefail

PROXY_PORT="${CODEWIZ_PROXY_PORT:-8089}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"
AVAILABLE_PROVIDERS="codewiz, openclaw, kimi, deepseek"

usage() {
    cat >&2 <<EOF
Usage: claude-use <command>

Commands:
  <provider>   Switch the claude proxy to the given provider
               Available: ${AVAILABLE_PROVIDERS}
  status       Show the current provider and proxy configuration
  -h           Show this help message

Examples:
  claude-use openclaw
  claude-use codewiz
  claude-use status
EOF
}

cmd="${1:-}"

case "$cmd" in
    -h|--help|"")
        usage
        exit 0
        ;;
    status)
        result=$(curl -sf "${PROXY_URL}/admin/status" 2>&1) || {
            echo "[claude-use] proxy not running at ${PROXY_URL}" >&2
            exit 1
        }
        echo "$result"
        ;;
    *)
        result=$(curl -sf "${PROXY_URL}/admin/switch?provider=${cmd}" 2>&1) || {
            echo "[claude-use] proxy not running at ${PROXY_URL}" >&2
            exit 1
        }
        echo "$result"
        ;;
esac
