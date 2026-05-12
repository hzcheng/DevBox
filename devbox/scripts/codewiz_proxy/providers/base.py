from __future__ import annotations

import abc


class BaseProvider(abc.ABC):
    @abc.abstractmethod
    def handle_anthropic(self, handler, body: bytes) -> None: ...

    @abc.abstractmethod
    def handle_openai(self, handler, body: bytes) -> None: ...
