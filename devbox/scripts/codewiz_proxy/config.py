from __future__ import annotations

import os
import ssl

TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_TARGET_URL",
    "https://codewiz.devops.xiaohongshu.com/llmadapter/v3/claude",
)
OPENAI_TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_OPENAI_TARGET_URL",
    "https://codewizllmproxy.devops.xiaohongshu.com/llmadapterproxy/v3/openai",
)
PORT = int(os.environ.get("CODEWIZ_PROXY_PORT", "8089"))

COWORK_BASE_URL = os.environ.get("COWORK_BASE_URL", "https://runway.devops.rednote.life/cowork")
COWORK_MODEL = os.environ.get("COWORK_MODEL", "global.anthropic.claude-opus-4.7")

_COWORK_KEY_PATH = os.path.join(os.environ.get("HOME", "/root"), ".cache", "codewiz-proxy", "cowork-key")


def _load_cowork_api_key() -> str:
    env = os.environ.get("COWORK_API_KEY", "")
    if env:
        return env
    try:
        with open(_COWORK_KEY_PATH) as f:
            return f.read().strip()
    except OSError:
        return ""


COWORK_API_KEY: str = _load_cowork_api_key()


def save_cowork_api_key(key: str) -> None:
    global COWORK_API_KEY
    COWORK_API_KEY = key
    try:
        key_dir = os.path.dirname(_COWORK_KEY_PATH)
        os.makedirs(key_dir, mode=0o700, exist_ok=True)
        os.chmod(key_dir, 0o700)
        with open(_COWORK_KEY_PATH, "w") as f:
            f.write(key)
        os.chmod(_COWORK_KEY_PATH, 0o600)
    except OSError as e:
        print(f"[config] cowork key 持久化失败: {e}", flush=True)

CODEWIZ_VERSION = "0.1.37"

METRICS_API = "http://codewiz.devops.xiaohongshu.com/complete/metrics/v1"
METRICS_EXTENDED_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/metrics-extended/batch"
LOG_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/logs/batch"

MODEL_MAP = {
    # Sonnet 4.6
    "claude-sonnet-4-6":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-6-20250627":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250514":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250929":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-20250514":    "claude-4.6-sonnet-google",
    "claude-sonnet-4-0":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-0-20250514":  "claude-4.6-sonnet-google",
    # Opus 4.6
    "claude-opus-4-6":             "claude-4.6-opus-google",
    "claude-opus-4-6-20250627":    "claude-4.6-opus-google",
    "claude-opus-4-0-20250515":    "claude-4.6-opus-google",
    # Opus 4.7
    "claude-opus-4-7":             "claude-4.7-opus-google",
    "claude-opus-4-7-20250514":    "claude-4.7-opus-google",
    # Haiku 4.5
    "claude-haiku-4-5":            "claude-4.5-haiku-google",
    "claude-haiku-4-5-20251001":   "claude-4.5-haiku-google",
}

# openai-native provider 的模型（GPT 系列，走内部网关但不需要额外 api-key header）
OPENAI_NATIVE_MODELS: frozenset[str] = frozenset({
    "gpt-5.3-codex",
    "gpt-5.4",
    "gpt-5.5",
})

# openai 兼容 provider 的模型（第三方，需附加 api-key header）
OPENAI_COMPAT_MODELS: frozenset[str] = frozenset({
    "deepseek-v4-flash",
    "deepseek-v4-pro",
    "glm-5.1",
    "glm-5v-turbo",
    "kimi-k2.5",
    "kimi-k2.5-qs",
    "kimi-k2.6",
    "kimi-k3-ali",
    "dots.llm2.inst",
})

# 第三方 openai 兼容模型需要附加的固定 header
# 默认值为内部网关固定 key，可通过环境变量覆盖
OPENAI_COMPAT_API_KEY_HEADER = "api-key"
OPENAI_COMPAT_API_KEY_VALUE = os.environ.get(
    "CODEWIZ_OPENAI_COMPAT_API_KEY",
    "QST2332f67caa6bdce8ae9fbd3524bdf2fa",
)

# ── 前缀路由 ──
# model name 格式 "<provider>:<alias>" 时，按此表解析出 provider 和实际 model。
# alias 先在 PREFIX_MODEL_ALIAS 中查找；找不到则原样透传给后端。
# 例：
#   "codewiz:sonnet"  → provider=codewiz, model=claude-4.6-sonnet-google
#   "lobi:opus"       → provider=lobi,    model=claude-4.6-opus-google
#   "cowork:opus"     → provider=cowork,  model 由 cowork provider 自决
PREFIX_PROVIDERS: frozenset[str] = frozenset({
    "codewiz", "lobi", "cowork",
})

# alias → 发送给后端的 model name
# 空字符串表示让 provider 用自己的默认模型（proxy 不覆盖 model 字段）
# 注意：cowork provider 会强制把 model 覆盖为 COWORK_MODEL，因此除 default 外的 alias 对其无实际影响
PREFIX_MODEL_ALIAS: dict[str, str] = {
    # Claude 落点别名
    "sonnet":           "claude-4.6-sonnet-google",
    "sonnet-thinking":  "claude-4.6-sonnet-google:thinking",
    "opus":             "claude-4.6-opus-google",
    "opus-thinking":    "claude-4.6-opus-google:thinking",
    "opus47":           "claude-4.7-opus-google",
    "haiku":            "claude-4.5-haiku-google",
    # OpenAI 落点别名（走内部网关 /v3/openai/v1）
    "gpt53":            "gpt-5.3-codex",
    "gpt54":            "gpt-5.4",
    "gpt55":            "gpt-5.5",
    "deepseek-flash":   "deepseek-v4-flash",
    "deepseek-pro":     "deepseek-v4-pro",
    "glm":              "glm-5.1",
    "glm5v":            "glm-5v-turbo",
    "kimi25":           "kimi-k2.5",
    "kimi25qs":         "kimi-k2.5-qs",
    "kimi26":           "kimi-k2.6",
    "kimi3":            "kimi-k3-ali",
    "dots":             "dots.llm2.inst",
    # 让 provider 自决
    "default":          "",
}

# Anthropic 专有字段，仅在 Anthropic 路径剥离
ANTHROPIC_STRIP_FIELDS: frozenset[str] = frozenset({
    "thinking", "output_config", "temperature_presets",
    "service_tier", "context_management", "betas", "metadata",
})

# OpenAI 路径剥离字段（排除 metadata / service_tier，这两个是 OpenAI 标准参数）
OPENAI_STRIP_FIELDS: frozenset[str] = frozenset({
    "thinking", "output_config", "temperature_presets",
    "context_management", "betas",
})

# 向后兼容别名，现有调用方统一用 ANTHROPIC_STRIP_FIELDS
STRIP_FIELDS = ANTHROPIC_STRIP_FIELDS

ALLOWED_BETA_PREFIXES = (
    "prompt-caching-2", "max-tokens-", "output-", "token-counting-",
    "interleaved-thinking-", "extended-cache-ttl-",
)

# ── 运行时可变全局状态（由 main() 写入） ──
VERBOSE: bool = False
LOG_FILE = None
ADAPTER_SOURCE: str = "codewiz-cli"

_SSL_CTX = ssl.create_default_context()
