#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
entrypoint="${repo_root}/devbox/scripts/start-services.sh"
python_bin="/usr/local/share/uv-tools/kimi-cli/bin/python"
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[ -x "${python_bin}" ] || fail "Kimi Python is missing: ${python_bin}"

# Load functions without starting container services.
source <(sed '/^main "\$@"$/d' "${entrypoint}")

declare -F setup_kimi_codewiz >/dev/null \
    || fail 'setup_kimi_codewiz is not defined'

DEV_USER=root
DEV_HOME="${tmp_dir}/home"
KIMI_CONFIGURE_PYTHON="${python_bin}"
mkdir -p "${DEV_HOME}/.kimi"
cat > "${DEV_HOME}/.kimi/config.toml" <<'EOF'
default_model = "keep/default"
default_thinking = false
custom_setting = "preserved"

[providers.keep]
type = "kimi"
base_url = "https://example.invalid/v1"
api_key = "keep"

[providers.codewiz]
type = "kimi"
base_url = "https://old.invalid/v1"
api_key = "old"

[models."keep/default"]
provider = "keep"
model = "keep-model"
max_context_size = 4096

[models."codewiz/kimi-k3"]
provider = "codewiz"
model = "old-model"
max_context_size = 4096
EOF

setup_kimi_codewiz
config_path="${DEV_HOME}/.kimi/config.toml"

"${python_bin}" - "${config_path}" <<'PY'
import sys
from pathlib import Path

import tomlkit

config = tomlkit.parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert config["default_model"] == "codewiz/kimi-k3"
assert config["default_thinking"] is True
assert config["custom_setting"] == "preserved"
assert config["providers"]["keep"]["base_url"] == "https://example.invalid/v1"
assert config["providers"]["codewiz"] == {
    "type": "kimi",
    "base_url": "http://127.0.0.1:8089/v1",
    "api_key": "dummy",
}
assert config["models"]["keep/default"]["model"] == "keep-model"
assert config["models"]["codewiz/kimi-k3"] == {
    "provider": "codewiz",
    "model": "kimi-k3",
    "max_context_size": 1000000,
    "capabilities": ["thinking", "image_in"],
}
PY

[ "$(stat -c '%a' "${config_path}")" = "600" ] \
    || fail 'Kimi config mode is not 600'

cp "${config_path}" "${tmp_dir}/first.toml"
setup_kimi_codewiz
cmp -s "${tmp_dir}/first.toml" "${config_path}" \
    || fail 'Kimi config merge is not idempotent'

bad_home="${tmp_dir}/bad-home"
mkdir -p "${bad_home}/.kimi"
printf '[broken\n' > "${bad_home}/.kimi/config.toml"
cp "${bad_home}/.kimi/config.toml" "${tmp_dir}/broken.toml"
DEV_HOME="${bad_home}"
setup_kimi_codewiz
cmp -s "${tmp_dir}/broken.toml" "${bad_home}/.kimi/config.toml" \
    || fail 'Malformed Kimi config was overwritten'

main_definition=$(declare -f main)
[[ "${main_definition}" == *'setup_kimi_codewiz'* ]] \
    || fail 'main does not invoke setup_kimi_codewiz'

printf 'PASS: Kimi CodeWiz config is merged safely and idempotently\n'
