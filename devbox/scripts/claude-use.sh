#!/usr/bin/env bash
# claude-use — inspect and configure the claude proxy at runtime.
# No container restart needed.
#
# Usage:
#   claude-use status              Show proxy status
#   claude-use cowork-key <key>    Save the cowork API key (persisted across restarts)
#   claude-use -h                  Show this help message
set -euo pipefail

PROXY_PORT="${CODEWIZ_PROXY_PORT:-8089}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"

usage() {
    cat >&2 <<EOF
Usage: claude-use <command>

Commands:
  status                Show proxy status (port, user)
  cowork-key <key>      Save the cowork API key (persisted across restarts)
  -h                    Show this help message

Examples:
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
        json_payload=$(python3 -c 'import json,sys; print(json.dumps({"key":sys.argv[1]}))' "$key")
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
        echo "[claude-use] unknown command: ${cmd}" >&2
        usage
        exit 1
        ;;
esac
