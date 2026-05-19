#!/usr/bin/env bash
# claude wrapper: auto-start codewiz proxy, then exec the real claude binary
_CLAUDE_PROXY_PORT=8089
_CLAUDE_CACHE_DIR="${HOME}/.cache/claude_proxy/codewiz"
_CLAUDE_PROXY_PY="/usr/local/lib/codewiz-proxy.py"
_CLAUDE_PROXY_URL="http://127.0.0.1:${_CLAUDE_PROXY_PORT}"

_proxy_is_healthy() {
    curl -sf --max-time 2 "${_CLAUDE_PROXY_URL}" >/dev/null 2>&1
}

_ensure_proxy() {
    _proxy_is_healthy && return 0
    mkdir -p "${_CLAUDE_CACHE_DIR}"
    local log_file="${_CLAUDE_CACHE_DIR}/proxy.log"
    local pid_file="${_CLAUDE_CACHE_DIR}/watchdog.pid"
    if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}" 2>/dev/null)" 2>/dev/null; then
        :
    else
        bash -c '
            pid_file='"'${pid_file}'"'
            log_file='"'${log_file}'"'
            port='"'${_CLAUDE_PROXY_PORT}'"'
            py='"'${_CLAUDE_PROXY_PY}'"'
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
        (( i++ )); [[ $i -ge 30 ]] && { echo "[claude-proxy] proxy not ready" >&2; return 1; }
        sleep 0.5
    done
}

_generate_preload() {
    local js="${_CLAUDE_CACHE_DIR}/preload.js"
    mkdir -p "${_CLAUDE_CACHE_DIR}"
    cat > "${js}" <<JSEOF
const http = require('http');
const https = require('https');
const PROXY_HOST = '127.0.0.1';
const PROXY_PORT = ${_CLAUDE_PROXY_PORT};
const REDIRECT_PATHS = ['/api/hello', '/v1/oauth/hello'];
function getUrlStr(o) {
    if (typeof o === 'string') return o;
    if (o instanceof URL) return o.href;
    return (o.protocol || 'https:') + '//' + (o.hostname || o.host || '') + (o.path || '/');
}
function shouldRedirect(o) {
    try { return REDIRECT_PATHS.includes(new URL(getUrlStr(o)).pathname); } catch(e) { return false; }
}
function getPath(o) {
    try { return new URL(getUrlStr(o)).pathname; } catch(e) { return o.path || '/'; }
}
['request','get'].forEach(function(m) {
    const orig = https[m].bind(https);
    https[m] = function(o, ...a) {
        if (shouldRedirect(o)) {
            return http[m]({host:PROXY_HOST,port:PROXY_PORT,path:getPath(o),method:m==='get'?'GET':(o.method||'GET'),headers:(typeof o==='object'&&o.headers)||{}}, ...a);
        }
        return orig(o, ...a);
    };
});
JSEOF
    echo "${js}"
}

# Ensure proxy is running (Claude Code settings.json already has endpoint config from cc-switch)
if _ensure_proxy; then
    preload_js="$(_generate_preload)"
    export NODE_OPTIONS="${NODE_OPTIONS:-} --require ${preload_js}"
fi

exec /usr/local/bin/claude.real "$@"
