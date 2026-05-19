from __future__ import annotations

import abc


class BaseProvider(abc.ABC):
    @abc.abstractmethod
    def handle_anthropic(
        self,
        handler,
        body: bytes,
        provider_registry: "dict[str, BaseProvider] | None" = None,
    ) -> None: ...

    @abc.abstractmethod
    def handle_openai(
        self,
        handler,
        body: bytes,
        provider_registry: "dict[str, BaseProvider] | None" = None,
    ) -> None: ...
