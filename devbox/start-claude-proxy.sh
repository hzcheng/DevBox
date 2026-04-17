#!/usr/bin/env bash
# Start the codewiz proxy watchdog in the background.
# Safe to call multiple times — does nothing if proxy is already running.
set -euo pipefail

PROXY_PORT=8089
PROXY_PY="/usr/local/lib/codewiz-proxy.py"
CACHE_DIR="${HOME}/.cache/claude_proxy/codewiz"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"
LOG_FILE="${CACHE_DIR}/proxy.log"
PID_FILE="${CACHE_DIR}/watchdog.pid"

if [ ! -f "${PROXY_PY}" ]; then
    echo "[claude-proxy] ${PROXY_PY} not found, skipping" >&2
    exit 0
fi

# Skip if a real Anthropic API key is configured
if [ -n "${ANTHROPIC_API_KEY:-}" ] && [ "${ANTHROPIC_API_KEY}" != "dummy" ]; then
    echo "[claude-proxy] ANTHROPIC_API_KEY is set, skipping proxy" >&2
    exit 0
fi

# Skip if no credentials available
if [ -z "${CODEWIZ_SESSION_TOKEN:-}" ] && \
   [ ! -f "${HOME}/.local/share/codewiz/auth.json" ]; then
    echo "[claude-proxy] no codewiz credentials found, skipping" >&2
    exit 0
fi

# Already running?
if curl -sf --max-time 2 "${PROXY_URL}" >/dev/null 2>&1; then
    echo "[claude-proxy] already running at ${PROXY_URL}" >&2
    exit 0
fi

mkdir -p "${CACHE_DIR}"

echo "[claude-proxy] starting watchdog..." >&2
bash -c '
    pid_file='"'${PID_FILE}'"'
    log_file='"'${LOG_FILE}'"'
    port='"'${PROXY_PORT}'"'
    py='"'${PROXY_PY}'"'
    echo "$$" > "${pid_file}"
    while true; do
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] starting proxy..." >> "${log_file}"
        CODEWIZ_PROXY_PORT="${port}" python3 "${py}" >> "${log_file}" 2>&1
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] proxy exited, restarting in 2s..." >> "${log_file}"
        sleep 2
    done
' >/dev/null 2>&1 &
disown $!

# Wait up to 15s for proxy to be ready
i=0
while ! curl -sf --max-time 2 "${PROXY_URL}" >/dev/null 2>&1; do
    i=$(( i + 1 ))
    if [ "${i}" -ge 30 ]; then
        echo "[claude-proxy] proxy not ready after 15s, check ${LOG_FILE}" >&2
        exit 1
    fi
    sleep 0.5
done

echo "[claude-proxy] ready at ${PROXY_URL}" >&2
