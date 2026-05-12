from __future__ import annotations

from .base import BaseProvider
from .codewiz import CodewizProvider
from .kimi import KimiProvider
from .deepseek import DeepseekProvider

PROVIDER_REGISTRY: dict[str, "BaseProvider"] = {
    "codewiz":  CodewizProvider(),
    "openclaw": CodewizProvider(adapter_source="openclaw"),
    "kimi":     KimiProvider(),
    "deepseek": DeepseekProvider(),
}
