from __future__ import annotations

from .base import BaseProvider
from .codewiz import CodewizProvider
from .kimi import KimiProvider
from .deepseek import DeepseekProvider
from .cowork import CoworkProvider

PROVIDER_REGISTRY: dict[str, "BaseProvider"] = {
    "codewiz":  CodewizProvider(),
    "lobi":     CodewizProvider(adapter_source="lobi"),
    "kimi":     KimiProvider(),
    "deepseek": DeepseekProvider(),
    "cowork":   CoworkProvider(),
}
