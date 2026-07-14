#!/usr/bin/env bash

set -uo pipefail

INTERVAL_SECONDS="${VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS:-600}"
MIN_AGE_SECONDS="${VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS:-1800}"
PROC_ROOT="${VSCODE_BRIDGE_REAPER_PROC_ROOT:-/proc}"
KILL_BIN="${VSCODE_BRIDGE_REAPER_KILL_BIN:-kill}"
CLOCK_TICKS="${VSCODE_BRIDGE_REAPER_CLOCK_TICKS:-$(getconf CLK_TCK 2>/dev/null || true)}"

run_once=false
dry_run=false

log_info() {
    printf '[INFO] %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

log_warn() {
    printf '[WARN] %s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

usage() {
    cat <<'EOF'
Usage: vscode-bridge-reaper.sh [--once] [--dry-run]

Periodically terminates old VS Code Dev Containers bridge helpers that no
longer have a live extension host with the same REMOTE_CONTAINERS_IPC value.
EOF
}

while (($# > 0)); do
    case "$1" in
        --once)
            run_once=true
            ;;
        --dry-run)
            dry_run=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_nonnegative_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

if ! is_positive_integer "${INTERVAL_SECONDS}"; then
    printf 'VSCODE_BRIDGE_REAPER_INTERVAL_SECONDS must be a positive integer\n' >&2
    exit 2
fi
if ! is_nonnegative_integer "${MIN_AGE_SECONDS}"; then
    printf 'VSCODE_BRIDGE_REAPER_MIN_AGE_SECONDS must be a non-negative integer\n' >&2
    exit 2
fi
if ! is_positive_integer "${CLOCK_TICKS}"; then
    printf 'VSCODE_BRIDGE_REAPER_CLOCK_TICKS must be a positive integer\n' >&2
    exit 2
fi
if [ ! -d "${PROC_ROOT}" ] || [ ! -r "${PROC_ROOT}/uptime" ]; then
    printf 'VSCODE_BRIDGE_REAPER_PROC_ROOT is not a readable proc filesystem: %s\n' "${PROC_ROOT}" >&2
    exit 2
fi
if ! command -v "${KILL_BIN}" >/dev/null 2>&1; then
    printf 'VSCODE_BRIDGE_REAPER_KILL_BIN is not executable: %s\n' "${KILL_BIN}" >&2
    exit 2
fi

read_cmdline() {
    local pid=$1
    local path="${PROC_ROOT}/${pid}/cmdline"

    [ -r "${path}" ] || return 1
    tr '\0' ' ' < "${path}" 2>/dev/null
}

read_ipc() {
    local pid=$1
    local path="${PROC_ROOT}/${pid}/environ"
    local ipc

    [ -r "${path}" ] || return 1
    ipc=$(tr '\0' '\n' < "${path}" 2>/dev/null \
        | sed -n 's/^REMOTE_CONTAINERS_IPC=//p' \
        | head -n 1) || return 1
    [ -n "${ipc}" ] || return 1
    printf '%s\n' "${ipc}"
}

read_age_seconds() {
    local pid=$1
    local uptime_seconds=$2
    local stat_line stat_tail start_ticks age_seconds
    local -a stat_fields

    [ -r "${PROC_ROOT}/${pid}/stat" ] || return 1
    IFS= read -r stat_line < "${PROC_ROOT}/${pid}/stat" || return 1
    [[ "${stat_line}" == *') '* ]] || return 1
    stat_tail=${stat_line#*) }
    read -r -a stat_fields <<< "${stat_tail}"
    # stat_fields starts at proc(5) field 3, so array index 19 is starttime (field 22).
    start_ticks=${stat_fields[19]:-}
    is_nonnegative_integer "${start_ticks}" || return 1

    age_seconds=$((uptime_seconds - start_ticks / CLOCK_TICKS))
    ((age_seconds >= 0)) || age_seconds=0
    printf '%s\n' "${age_seconds}"
}

scan_once() {
    local uptime_value uptime_seconds proc_dir pid cmdline ipc age_seconds
    local examined=0 active=0 young=0 metadata_protected=0 candidates=0 terminated=0
    local -A active_ipcs=()

    IFS=' ' read -r uptime_value _ < "${PROC_ROOT}/uptime" || {
        log_warn "Cannot read ${PROC_ROOT}/uptime; skipping this scan"
        return 0
    }
    uptime_seconds=${uptime_value%%.*}
    if ! is_nonnegative_integer "${uptime_seconds}"; then
        log_warn "Invalid uptime value; skipping this scan"
        return 0
    fi

    for proc_dir in "${PROC_ROOT}"/[0-9]*; do
        [ -d "${proc_dir}" ] || continue
        pid=${proc_dir##*/}
        cmdline=$(read_cmdline "${pid}") || continue
        [[ "${cmdline}" == *'--type=extensionHost'* ]] || continue
        ipc=$(read_ipc "${pid}") || continue
        active_ipcs["${ipc}"]=1
    done

    for proc_dir in "${PROC_ROOT}"/[0-9]*; do
        [ -d "${proc_dir}" ] || continue
        pid=${proc_dir##*/}
        cmdline=$(read_cmdline "${pid}") || continue
        [[ "${cmdline}" == *'vscode-remote-containers-server-'*'.js'* ]] || continue
        ((examined += 1))

        ipc=$(read_ipc "${pid}") || {
            ((metadata_protected += 1))
            continue
        }
        age_seconds=$(read_age_seconds "${pid}" "${uptime_seconds}") || {
            ((metadata_protected += 1))
            continue
        }

        if [[ -n "${active_ipcs[${ipc}]+set}" ]]; then
            ((active += 1))
        elif ((age_seconds < MIN_AGE_SECONDS)); then
            ((young += 1))
        else
            ((candidates += 1))
            if [ "${dry_run}" = false ]; then
                if "${KILL_BIN}" -TERM "${pid}"; then
                    ((terminated += 1))
                else
                    log_warn "Failed to terminate stale bridge pid=${pid} age=${age_seconds}s"
                fi
            fi
        fi
    done

    log_info "VS Code bridge scan complete examined=${examined} active=${active} young=${young} metadata_protected=${metadata_protected} candidates=${candidates} terminated=${terminated} dry_run=${dry_run}"
}

while true; do
    scan_once
    [ "${run_once}" = true ] && break
    sleep "${INTERVAL_SECONDS}"
done
