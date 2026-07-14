#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
reaper="${repo_root}/devbox/scripts/vscode-bridge-reaper.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

proc_root="${tmp_dir}/proc"
kill_log="${tmp_dir}/kill.log"
fake_kill="${tmp_dir}/fake-kill"
mkdir -p "${proc_root}"
printf '1000.00 0.00\n' > "${proc_root}/uptime"
: > "${kill_log}"

cat > "${fake_kill}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${VSCODE_BRIDGE_REAPER_TEST_KILL_LOG}"
EOF
chmod +x "${fake_kill}"
export VSCODE_BRIDGE_REAPER_TEST_KILL_LOG="${kill_log}"

write_stat() {
    local pid=$1
    local start_ticks=$2
    local field

    mkdir -p "${proc_root}/${pid}"
    printf '%s (node) S' "${pid}" > "${proc_root}/${pid}/stat"
    for ((field = 4; field <= 21; field++)); do
        printf ' 0' >> "${proc_root}/${pid}/stat"
    done
    printf ' %s\n' "${start_ticks}" >> "${proc_root}/${pid}/stat"
}

write_bridge() {
    local pid=$1
    local start_ticks=$2
    local ipc=${3:-}

    write_stat "${pid}" "${start_ticks}"
    printf '/vscode/node\0/tmp/vscode-remote-containers-server-test-%s.js\0' \
        "${pid}" > "${proc_root}/${pid}/cmdline"
    if [ -n "${ipc}" ]; then
        printf 'REMOTE_CONTAINERS_IPC=%s\0' "${ipc}" > "${proc_root}/${pid}/environ"
    else
        : > "${proc_root}/${pid}/environ"
    fi
}

write_extension_host() {
    local pid=$1
    local start_ticks=$2
    local ipc=$3

    write_stat "${pid}" "${start_ticks}"
    printf '/vscode/node\0--type=extensionHost\0' > "${proc_root}/${pid}/cmdline"
    printf 'REMOTE_CONTAINERS_IPC=%s\0' "${ipc}" > "${proc_root}/${pid}/environ"
}

assert_contains() {
    local haystack=$1
    local needle=$2

    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf 'FAIL: expected output to contain %q\noutput:\n%s\n' "${needle}" "${haystack}" >&2
        exit 1
    fi
}

assert_kill_log() {
    local expected=$1
    local actual

    actual=$(<"${kill_log}")
    if [ "${actual}" != "${expected}" ]; then
        printf 'FAIL: expected kill log %q, got %q\n' "${expected}" "${actual}" >&2
        exit 1
    fi
}

assert_file_contains() {
    local path=$1
    local needle=$2

    if ! grep -Fq -- "${needle}" "${path}"; then
        printf 'FAIL: expected %s to contain %q\n' "${path}" "${needle}" >&2
        exit 1
    fi
}

# At 1000 seconds of uptime with 100 clock ticks per second:
# - start tick 10000 is 900 seconds old.
# - start tick 95000 is 50 seconds old.
write_bridge 101 10000 /tmp/active.sock
write_bridge 102 10000 /tmp/stale.sock
write_bridge 103 95000 /tmp/young.sock
write_bridge 104 10000
write_extension_host 201 10000 /tmp/active.sock

if [ ! -x "${reaper}" ]; then
    printf 'FAIL: reaper is missing or not executable: %s\n' "${reaper}" >&2
    exit 1
fi

actual_mode=$(stat -c '%a' "${reaper}")
if [ "${actual_mode}" != 755 ]; then
    printf 'FAIL: expected reaper mode 755, got %s\n' "${actual_mode}" >&2
    exit 1
fi

output=$(
    VSCODE_BRIDGE_REAPER_PROC_ROOT="${proc_root}" \
    VSCODE_BRIDGE_REAPER_KILL_BIN="${fake_kill}" \
    VSCODE_BRIDGE_REAPER_CLOCK_TICKS=100 \
    VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=100 \
        "${reaper}" --once
)

assert_kill_log '-TERM 102'
assert_contains "${output}" 'examined=4'
assert_contains "${output}" 'active=1'
assert_contains "${output}" 'young=1'
assert_contains "${output}" 'metadata_protected=1'
assert_contains "${output}" 'candidates=1'
assert_contains "${output}" 'terminated=1'

: > "${kill_log}"
dry_run_output=$(
    VSCODE_BRIDGE_REAPER_PROC_ROOT="${proc_root}" \
    VSCODE_BRIDGE_REAPER_KILL_BIN="${fake_kill}" \
    VSCODE_BRIDGE_REAPER_CLOCK_TICKS=100 \
    VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=100 \
        "${reaper}" --once --dry-run
)

assert_kill_log ''
assert_contains "${dry_run_output}" 'candidates=1'
assert_contains "${dry_run_output}" 'terminated=0'
assert_contains "${dry_run_output}" 'dry_run=true'

if VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS=0 "${reaper}" --once >/dev/null 2>&1; then
    printf 'FAIL: zero scan interval should be rejected\n' >&2
    exit 1
fi
if VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=-1 "${reaper}" --once >/dev/null 2>&1; then
    printf 'FAIL: negative minimum age should be rejected\n' >&2
    exit 1
fi
if "${reaper}" --unknown >/dev/null 2>&1; then
    printf 'FAIL: unknown arguments should be rejected\n' >&2
    exit 1
fi

assert_file_contains "${repo_root}/devbox/Dockerfile" \
    'COPY devbox/scripts/vscode-bridge-reaper.sh /usr/local/bin/vscode-bridge-reaper'
assert_file_contains "${repo_root}/devbox/Dockerfile" \
    'chmod 0755 /usr/local/bin/vscode-bridge-reaper'
assert_file_contains "${repo_root}/devbox/docker-compose.yml" \
    'VSCODE_BRIDGE_REAPER_ENABLED=${VSCODE_BRIDGE_REAPER_ENABLED:-true}'
assert_file_contains "${repo_root}/devbox/docker-compose.yml" \
    'VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS=${VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS:-600}'
assert_file_contains "${repo_root}/devbox/docker-compose.yml" \
    'VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS=${VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS:-1800}'
assert_file_contains "${repo_root}/devbox/scripts/start-services.sh" \
    'setup_vscode_bridge_reaper()'
assert_file_contains "${repo_root}/.example.env" \
    'VSCODE_BRIDGE_REAPER_ENABLED=true'

printf 'PASS: vscode bridge reaper protects active, young, and unclassifiable bridges\n'
