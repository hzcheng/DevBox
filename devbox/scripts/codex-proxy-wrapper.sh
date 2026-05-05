#!/usr/bin/env bash
# codex wrapper: auto-start codewiz proxy (shared with claude), then exec the real codex binary.
# The same proxy on port 8089 handles both Anthropic and OpenAI API formats.
_CODEX_PROXY_PORT=8089
_CODEX_CACHE_DIR="${HOME}/.cache/claude_proxy/codewiz"
_CODEX_PROXY_PY="/usr/local/lib/codewiz-proxy.py"
_CODEX_PROXY_URL="http://127.0.0.1:${_CODEX_PROXY_PORT}"

_proxy_is_healthy() {
    curl -sf --max-time 2 "${_CODEX_PROXY_URL}" >/dev/null 2>&1
}

_ensure_proxy() {
    _proxy_is_healthy && return 0
    mkdir -p "${_CODEX_CACHE_DIR}"
    local log_file="${_CODEX_CACHE_DIR}/proxy.log"
    local pid_file="${_CODEX_CACHE_DIR}/watchdog.pid"
    if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}" 2>/dev/null)" 2>/dev/null; then
        :
    else
        bash -c '
            pid_file='"'${pid_file}'"'
            log_file='"'${log_file}'"'
            port='"'${_CODEX_PROXY_PORT}'"'
            py='"'${_CODEX_PROXY_PY}'"'
            echo "$$" > "${pid_file}"
            while true; do
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] starting proxy..." >> "${log_file}"
                CODEWIZ_PROXY_PORT="${port}" python3 "${py}" >> "${log_file}" 2>&1
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] proxy exited, restarting in 2s..." >> "${log_file}"
                sleep 2
            done
        ' >/dev/null 2>&1 &
        disown $!
    fi
    local i=0
    while ! _proxy_is_healthy; do
        (( i++ )); [[ $i -ge 30 ]] && { echo "[codex-proxy] proxy not ready" >&2; return 1; }
        sleep 0.5
    done
}

# Skip proxy if a real OpenAI API key is already configured
if [[ -z "${OPENAI_API_KEY:-}" || "${OPENAI_API_KEY}" == "dummy" ]]; then
    if _ensure_proxy; then
        export OPENAI_BASE_URL="${_CODEX_PROXY_URL}"
        export OPENAI_API_KEY="dummy"
        # Treat the local proxy as a custom provider so Codex stays on HTTP
        # responses instead of attempting websocket upgrades that this proxy
        # does not implement.
        _CODEX_PROVIDER_ARGS=(
            -c 'model_provider="codewiz"'
            -c 'model_providers.codewiz={name="codewiz",base_url="http://127.0.0.1:8089",wire_api="responses",requires_openai_auth=false,supports_websockets=false}'
        )
        exec node /usr/local/bin/codex.real "${_CODEX_PROVIDER_ARGS[@]}" "$@"
    fi
fi

exec node /usr/local/bin/codex.real "$@"
