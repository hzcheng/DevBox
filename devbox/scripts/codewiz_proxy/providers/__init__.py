from __future__ import annotations

from .base import BaseProvider
from .codewiz import CodewizProvider
from .cowork import CoworkProvider

PROVIDER_REGISTRY: dict[str, "BaseProvider"] = {
    "codewiz": CodewizProvider(),
    "lobi":    CodewizProvider(adapter_source="openclaw"),
    "cowork":  CoworkProvider(),
}
