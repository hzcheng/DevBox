#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
dockerfile="${repo_root}/devbox/Dockerfile"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_file_contains() {
    local path=$1
    local needle=$2

    if ! grep -Fq -- "${needle}" "${path}"; then
        fail "expected ${path} to contain ${needle}"
    fi
}

assert_file_contains "${dockerfile}" \
    'https://cli.github.com/packages/githubcli-archive-keyring.gpg'
assert_file_contains "${dockerfile}" \
    '/etc/apt/sources.list.d/github-cli.list'
assert_file_contains "${dockerfile}" \
    'https://cli.github.com/packages stable main'
assert_file_contains "${dockerfile}" \
    'githubcli-archive-keyring.gpg'
assert_file_contains "${dockerfile}" \
    ' gh '

printf 'PASS: Dockerfile installs GitHub CLI from the official apt repository\n'
