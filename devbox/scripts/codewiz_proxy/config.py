from __future__ import annotations

import os
import ssl
import threading

TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_TARGET_URL",
    "https://codewiz.devops.xiaohongshu.com/llmadapter/v3/claude",
)
OPENAI_TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_OPENAI_TARGET_URL",
    "https://codewiz.devops.xiaohongshu.com/llmratelimit/v3/openai/v1",
)
PORT = int(os.environ.get("CODEWIZ_PROXY_PORT", "8089"))

KIMI_TARGET_BASE_URL = "https://api.kimi.com/coding"
KIMI_MODEL = "kimi-for-coding"
KIMI_USER_AGENT = "KimiCLI/1.37.0"
KIMI_CREDENTIALS_PATH = os.path.join(os.environ.get("HOME", "/root"), ".kimi", "credentials", "kimi-code.json")
KIMI_OAUTH_TOKEN_URL = "https://auth.kimi.com/api/oauth/token"

DEEPSEEK_ANTHROPIC_BASE_URL = os.environ.get("DEEPSEEK_API_URL") or "https://api.deepseek.com/anthropic"
DEEPSEEK_OPENAI_BASE_URL = "https://api.deepseek.com"
DEEPSEEK_MODEL = "deepseek-v4-pro"
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")

CODEWIZ_VERSION = "0.1.37"

METRICS_API = "http://codewiz.devops.xiaohongshu.com/complete/metrics/v1"
METRICS_EXTENDED_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/metrics-extended/batch"
LOG_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/logs/batch"

MODEL_MAP = {
    "claude-sonnet-4-6":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-6-20250627":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250514":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250929":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-20250514":    "claude-4.6-sonnet-google",
    "claude-opus-4-6":             "claude-4.6-opus-google",
    "claude-opus-4-6-20250627":    "claude-4.6-opus-google",
    "claude-opus-4-0-20250515":    "claude-4.6-opus-google",
    "claude-haiku-4-5":            "claude-4.5-haiku-google",
    "claude-haiku-4-5-20251001":   "claude-4.5-haiku-google",
    "claude-sonnet-4-0":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-0-20250514":  "claude-4.6-sonnet-google",
}

STRIP_FIELDS = {
    "thinking", "output_config", "temperature_presets",
    "service_tier", "context_management", "betas", "metadata",
}

ALLOWED_BETA_PREFIXES = (
    "prompt-caching-2", "max-tokens-", "output-", "token-counting-",
    "interleaved-thinking-", "extended-cache-ttl-",
)

# ── 运行时可变全局状态（由 main() 写入） ──
VERBOSE: bool = False
LOG_FILE = None
ADAPTER_SOURCE: str = "codewiz-cli"

_SSL_CTX = ssl.create_default_context()

# ── Provider 状态（运行时可切换，重启后持久化） ──
_PROVIDER_STATE_PATH = os.path.join(
    os.environ.get("HOME", "/root"), ".cache", "codewiz-proxy", "provider"
)

_PROVIDER_LOCK = threading.Lock()


def _load_persisted_provider() -> str:
    env = os.environ.get("CODEWIZ_INITIAL_PROVIDER", "")
    if env:
        return env
    try:
        with open(_PROVIDER_STATE_PATH) as f:
            name = f.read().strip()
        if name:
            return name
    except OSError:
        pass
    return "codewiz"


_CURRENT_PROVIDER: str = _load_persisted_provider()


def get_provider() -> str:
    with _PROVIDER_LOCK:
        return _CURRENT_PROVIDER


def set_provider(name: str) -> None:
    global _CURRENT_PROVIDER
    with _PROVIDER_LOCK:
        _CURRENT_PROVIDER = name
    try:
        os.makedirs(os.path.dirname(_PROVIDER_STATE_PATH), exist_ok=True)
        with open(_PROVIDER_STATE_PATH, "w") as f:
            f.write(name)
        os.chmod(_PROVIDER_STATE_PATH, 0o600)
    except OSError:
        pass
