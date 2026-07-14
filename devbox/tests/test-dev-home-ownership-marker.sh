#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
entrypoint="${repo_root}/devbox/scripts/start-services.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

# Load the real functions without invoking the container entrypoint.
source <(sed '/^main "\$@"$/d' "${entrypoint}")

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

if ! declare -F dev_home_ownership_marker >/dev/null; then
    fail 'dev_home_ownership_marker is not defined'
fi

DEV_HOME="${tmp_dir}/home"
marker=$(dev_home_ownership_marker 1001 1001)
expected="${DEV_HOME}/.cache/devbox/ownership-initialized-1001-1001"
[ "${marker}" = "${expected}" ] \
    || fail "expected marker ${expected}, got ${marker}"

mkdir -p "$(dirname "${marker}")"
touch "${marker}"
[ -f "$(dev_home_ownership_marker 1001 1001)" ] \
    || fail 'same UID/GID did not reuse the persistent marker'
[ ! -f "$(dev_home_ownership_marker 1002 1001)" ] \
    || fail 'changed UID unexpectedly reused the old marker'
[ ! -f "$(dev_home_ownership_marker 1001 1002)" ] \
    || fail 'changed GID unexpectedly reused the old marker'

setup_definition=$(declare -f setup_dev_user)
[[ "${setup_definition}" == *'dev_home_ownership_marker'* ]] \
    || fail 'setup_dev_user does not use the persistent ownership marker'
[[ "${setup_definition}" != *'/var/lib/devbox-initialized-'* ]] \
    || fail 'setup_dev_user still uses the container-local ownership marker'

printf 'PASS: ownership marker persists in DEV_HOME and is keyed by UID/GID\n'
