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
AVAILABLE_PROVIDERS="codewiz, lobi, kimi, deepseek, cowork"

usage() {
    cat >&2 <<EOF
Usage: claude-use <command>

Commands:
  <provider>        Switch the claude proxy to the given provider
                    Available: ${AVAILABLE_PROVIDERS}
  status            Show the current provider and proxy configuration
  cowork-key <key>  Save the cowork API key (persisted across restarts)
  -h                Show this help message

Examples:
  claude-use cowork
  claude-use codewiz
  claude-use status
  claude-use cowork-key 4f5bf0de5a5d4df6a2ca00b4cdcdcf0a
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
    cowork-key)
        key="${2:-}"
        if [ -z "$key" ]; then
            echo "[claude-use] usage: claude-use cowork-key <key>" >&2
            exit 1
        fi
        json_payload=$(printf '%s' "$key" | python3 -c 'import json,sys; print(json.dumps({"key":sys.stdin.read()}))')
        result=$(curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            "${PROXY_URL}/admin/set-key?provider=cowork" 2>&1) || {
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
