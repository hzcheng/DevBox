# Kimi CLI via CodeWiz K3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Kimi CLI to use CodeWiz's `kimi-k3-ali` model by default through DevBox's existing local CodeWiz proxy.

**Architecture:** Add K3 to the proxy's OpenAI-compatible model registry, then merge a DevBox-owned provider and model alias into `${DEV_HOME}/.kimi/config.toml` during container startup. The Kimi config points at `127.0.0.1:8089`, so the proxy—not Kimi's config—owns all CodeWiz SSO credential handling.

**Tech Stack:** Bash, Python 3, `tomlkit` from the installed `kimi-cli` tool environment, Docker Compose, Python `unittest`.

## Global Constraints

- The upstream model identifier is exactly `kimi-k3-ali`.
- The Kimi model alias is exactly `codewiz/kimi-k3`.
- The Kimi provider base URL is exactly `http://127.0.0.1:8089/v1`.
- Do not copy SSO tokens, user email addresses, or the internal compatibility key into Kimi's config.
- Preserve unrelated Kimi settings, providers, and models.
- Update only `default_model`, `default_thinking`, `providers.codewiz`, and `models."codewiz/kimi-k3"`.
- The resulting Kimi config must be owned by `DEV_USER` and have mode `0600`.
- Preserve all pre-existing unrelated worktree changes, including the current Dockerfile and VS Code settings edits.

## File Structure

- Modify `devbox/scripts/codewiz_proxy/config.py`: classify and alias the K3 model.
- Create `devbox/tests/test-codewiz-kimi-k3.py`: verify the proxy registry and alias.
- Modify `devbox/scripts/start-services.sh`: merge Kimi configuration at startup using Kimi CLI's bundled `tomlkit`.
- Create `devbox/tests/test-kimi-codewiz-config.sh`: verify merge behavior, idempotency, error safety, and startup wiring.

---

### Task 1: Register Kimi K3 in the CodeWiz proxy

**Files:**
- Modify: `devbox/scripts/codewiz_proxy/config.py:85-95`
- Modify: `devbox/scripts/codewiz_proxy/config.py:126-138`
- Create: `devbox/tests/test-codewiz-kimi-k3.py`

**Interfaces:**
- Consumes: existing `OPENAI_COMPAT_MODELS` and `PREFIX_MODEL_ALIAS` registries.
- Produces: `kimi-k3-ali` compatibility classification and the `kimi3` alias used by all proxy paths.

- [ ] **Step 1: Write the failing registry test**

Create `devbox/tests/test-codewiz-kimi-k3.py`:

```python
#!/usr/bin/env python3

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "devbox" / "scripts"))

from codewiz_proxy import config  # noqa: E402


class KimiK3ProxyConfigTest(unittest.TestCase):
    def test_kimi_k3_is_openai_compatible(self) -> None:
        self.assertIn("kimi-k3-ali", config.OPENAI_COMPAT_MODELS)

    def test_kimi3_alias_uses_codewiz_model_id(self) -> None:
        self.assertEqual(config.PREFIX_MODEL_ALIAS["kimi3"], "kimi-k3-ali")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
python3 devbox/tests/test-codewiz-kimi-k3.py
```

Expected: one assertion failure because `kimi-k3-ali` is absent and one
`KeyError` because `kimi3` is absent.

- [ ] **Step 3: Add the K3 model and alias**

Add the model beside the existing Kimi entries in `OPENAI_COMPAT_MODELS`:

```python
    "kimi-k2.6",
    "kimi-k3-ali",
    "dots.llm2.inst",
```

Add the alias beside the existing Kimi aliases in `PREFIX_MODEL_ALIAS`:

```python
    "kimi26":           "kimi-k2.6",
    "kimi3":            "kimi-k3-ali",
    "dots":             "dots.llm2.inst",
```

- [ ] **Step 4: Run the focused test**

Run:

```bash
python3 devbox/tests/test-codewiz-kimi-k3.py
```

Expected:

```text
..
----------------------------------------------------------------------
Ran 2 tests

OK
```

- [ ] **Step 5: Commit the proxy registry change**

Run:

```bash
git add devbox/scripts/codewiz_proxy/config.py devbox/tests/test-codewiz-kimi-k3.py
git commit -m "feat(codewiz): register Kimi K3 model"
```

Expected: the commit contains only the proxy registry and its focused test.

---

### Task 2: Merge the Kimi provider configuration at startup

**Files:**
- Modify: `devbox/scripts/start-services.sh:118`
- Modify: `devbox/scripts/start-services.sh:329-351`
- Create: `devbox/tests/test-kimi-codewiz-config.sh`

**Interfaces:**
- Consumes: `DEV_USER`, `DEV_HOME`, `gosu`, and `/usr/local/share/uv-tools/kimi-cli/bin/python`.
- Produces: `setup_kimi_codewiz()`, which safely merges the managed Kimi configuration and always leaves unrelated configuration untouched.

- [ ] **Step 1: Write the failing startup configuration test**

Create `devbox/tests/test-kimi-codewiz-config.sh`:

```bash
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
    "model": "kimi-k3-ali",
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
```

Make the test executable:

```bash
chmod +x devbox/tests/test-kimi-codewiz-config.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
devbox/tests/test-kimi-codewiz-config.sh
```

Expected:

```text
FAIL: setup_kimi_codewiz is not defined
```

- [ ] **Step 3: Add `setup_kimi_codewiz`**

Insert this function after `setup_dev_user` in
`devbox/scripts/start-services.sh`:

```bash
# ============================================
# Kimi CLI CodeWiz provider 配置
# ============================================
setup_kimi_codewiz() {
    local python_bin="${KIMI_CONFIGURE_PYTHON:-/usr/local/share/uv-tools/kimi-cli/bin/python}"
    local -a command

    if [ ! -x "${python_bin}" ]; then
        log_warn "Kimi Python not found at ${python_bin}, skipping Kimi CodeWiz config"
        return 0
    fi

    if [ "${DEV_USER}" != "root" ]; then
        command=(env HOME="${DEV_HOME}" gosu "${DEV_USER}" "${python_bin}" - "${DEV_HOME}")
    else
        command=(env HOME="${DEV_HOME}" "${python_bin}" - "${DEV_HOME}")
    fi

    if "${command[@]}" <<'PY'
import os
import sys
import tempfile
from pathlib import Path

import tomlkit


home = Path(sys.argv[1])
config_dir = home / ".kimi"
config_path = config_dir / "config.toml"
config_dir.mkdir(parents=True, exist_ok=True)

if config_path.exists():
    document = tomlkit.parse(config_path.read_text(encoding="utf-8"))
else:
    document = tomlkit.document()

document["default_model"] = "codewiz/kimi-k3"
document["default_thinking"] = True

providers = document.get("providers")
if not isinstance(providers, dict):
    providers = tomlkit.table()
    document["providers"] = providers
providers["codewiz"] = {
    "type": "kimi",
    "base_url": "http://127.0.0.1:8089/v1",
    "api_key": "dummy",
}

models = document.get("models")
if not isinstance(models, dict):
    models = tomlkit.table()
    document["models"] = models
models["codewiz/kimi-k3"] = {
    "provider": "codewiz",
    "model": "kimi-k3-ali",
    "max_context_size": 1000000,
    "capabilities": ["thinking", "image_in"],
}

fd, temp_name = tempfile.mkstemp(prefix=".config.toml.", dir=config_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as temp_file:
        temp_file.write(tomlkit.dumps(document))
        temp_file.flush()
        os.fsync(temp_file.fileno())
    os.chmod(temp_name, 0o600)
    os.replace(temp_name, config_path)
except BaseException:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    raise
PY
    then
        log_info "Kimi CLI configured for CodeWiz K3"
    else
        log_warn "Failed to configure Kimi CLI for CodeWiz K3; existing config preserved"
    fi
}
```

This implementation uses the Python environment installed with Kimi CLI
because it already includes `tomlkit`; no package is added to the image.
Running the merge through `gosu` for a non-root `DEV_USER` gives the resulting
directory and file the correct owner.

- [ ] **Step 4: Invoke the setup after home initialization**

Add this call immediately after `setup_dev_user` in `main`:

```bash
    # 0.2 配置 Kimi CLI 使用本地 CodeWiz proxy 的 K3 模型
    setup_kimi_codewiz
```

- [ ] **Step 5: Run the focused test**

Run:

```bash
devbox/tests/test-kimi-codewiz-config.sh
```

Expected output includes one warning for the deliberately malformed fixture
and ends with:

```text
PASS: Kimi CodeWiz config is merged safely and idempotently
```

- [ ] **Step 6: Check Bash syntax**

Run:

```bash
bash -n devbox/scripts/start-services.sh
bash -n devbox/tests/test-kimi-codewiz-config.sh
```

Expected: both commands exit zero with no output.

- [ ] **Step 7: Commit the startup integration**

Run:

```bash
git add devbox/scripts/start-services.sh devbox/tests/test-kimi-codewiz-config.sh
git commit -m "feat(kimi): route K3 through CodeWiz proxy"
```

Expected: the commit contains only startup configuration and its test.

---

### Task 3: Verify the complete DevBox flow

**Files:**
- Verify only; no file changes expected.

**Interfaces:**
- Consumes: Task 1's proxy registry and Task 2's startup configuration.
- Produces: evidence that static validation, image construction, container startup, proxy routing, and Kimi CLI inference work together.

- [ ] **Step 1: Run all focused repository tests**

Run:

```bash
python3 devbox/tests/test-codewiz-kimi-k3.py
devbox/tests/test-kimi-codewiz-config.sh
devbox/tests/test-dev-home-ownership-marker.sh
devbox/tests/test-vscode-bridge-reaper.sh
```

Expected: all four commands exit zero and each suite ends in `OK` or `PASS`.

- [ ] **Step 2: Validate shell and Compose configuration**

Run:

```bash
bash -n devbox/scripts/start-services.sh
docker compose config
```

Expected: Bash exits silently with zero; Compose prints the normalized project
configuration and exits zero.

- [ ] **Step 3: Build and start DevBox**

Run:

```bash
docker compose build devbox
docker compose up -d
docker compose ps
```

Expected: the build succeeds, `up` exits zero, and `docker compose ps` reports
the `devbox` service as running.

- [ ] **Step 4: Verify generated Kimi configuration inside the container**

Run:

```bash
docker compose exec -T devbox \
  /usr/local/share/uv-tools/kimi-cli/bin/python - <<'PY'
from pathlib import Path

import tomlkit

config = tomlkit.parse(Path.home().joinpath(".kimi/config.toml").read_text())
assert config["default_model"] == "codewiz/kimi-k3"
assert config["providers"]["codewiz"]["base_url"] == "http://127.0.0.1:8089/v1"
assert config["providers"]["codewiz"]["api_key"] == "dummy"
assert config["models"]["codewiz/kimi-k3"]["model"] == "kimi-k3-ali"
print("PASS: container Kimi config uses local CodeWiz K3")
PY
```

Expected:

```text
PASS: container Kimi config uses local CodeWiz K3
```

- [ ] **Step 5: Verify proxy health and Kimi inference**

Run:

```bash
docker compose exec -T devbox curl -fsS http://127.0.0.1:8089/api/hello
docker compose exec -T devbox \
  kimi --quiet --prompt '只回复 OK，不要添加其他内容。'
```

Expected: the health check returns `{"status": "ok"}` and Kimi prints `OK` with
exit status zero. If credentials are absent, stop here and report the existing
CodeWiz login prerequisite rather than changing authentication behavior.

- [ ] **Step 6: Verify service and SSH reachability**

Run:

```bash
docker compose ps
docker compose port devbox 22
```

Expected: DevBox remains running and Compose prints a host binding for
container port 22. Confirm that printed host port is reachable with the
environment's standard TCP check.

- [ ] **Step 7: Confirm only intended files changed**

Run:

```bash
git status --short
git log -3 --oneline
```

Expected: the pre-existing unrelated changes remain present and unstaged; the
two implementation commits appear above the design and plan commits.
