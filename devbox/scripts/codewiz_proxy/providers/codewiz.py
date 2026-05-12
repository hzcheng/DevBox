from __future__ import annotations

import json
import urllib.request

from .. import config, credentials
from ..utils import log, rewrite_body, filter_beta_header, extract_billing_header
from ..telemetry import SESSION
from ..forward import forward
from .base import BaseProvider


class CodewizProvider(BaseProvider):
    def __init__(self, adapter_source: str | None = None):
        self._adapter_source = adapter_source

    def _effective_adapter_source(self) -> str:
        return self._adapter_source or config.ADAPTER_SOURCE

    def handle_anthropic(self, handler, body: bytes) -> None:
        body, body_json, extra_headers, rewrite_logs, model_id = rewrite_body(body)
        for info in rewrite_logs:
            log(f"  [rewrite] {info}")

        if body_json:
            log(f"  model: {body_json.get('model', 'N/A')}  "
                f"stream: {body_json.get('stream', 'N/A')}  "
                f"messages: {len(body_json.get('messages', []))} 条")
            if config.VERBOSE:
                log(json.dumps(body_json, indent=2, ensure_ascii=False))
        else:
            log(f"  [body 解析失败, 长度: {len(body)} bytes]")

        target_url = config.TARGET_BASE_URL + handler.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            if key.lower() == "anthropic-beta":
                filtered = filter_beta_header(value)
                if filtered:
                    req.add_header(key, filtered)
                    if filtered != value:
                        log(f"  [beta] {value} -> {filtered}")
                else:
                    log("  [beta] 移除（全部不在白名单）")
                continue
            req.add_header(key, value)

        req.add_header("Cookie", f"{credentials.SSO_TOKEN_KEY}={credentials.SESSION_TOKEN}")
        req.add_header(credentials.SSO_TOKEN_KEY, credentials.SESSION_TOKEN)
        req.add_header("x-adapter-source", self._effective_adapter_source())
        req.add_header("x-adapter-email", credentials.USER_EMAIL)
        req.add_header("X-Adapter-User-Email", credentials.USER_EMAIL)
        req.add_header("x-adapter-scenario", "codewiz-opencode-cli")

        for hk, hv in extra_headers.items():
            req.add_header(hk, hv)

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        should_report = bool(model_id and n % 3 == 0)

        forward(handler, req, body_json, model_id, n, session_id, conversation_id, should_report)

    def handle_openai(self, handler, body: bytes) -> None:
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        if isinstance(body_json.get("system"), list):
            _, _ = extract_billing_header(body_json)
            body = json.dumps(body_json).encode("utf-8")

        model = body_json.get("model", "N/A")
        log(f"  [openai] model: {model}  path: {handler.path}")
        if config.VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        target_url = config.OPENAI_TARGET_BASE_URL + handler.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-anthropic-billing-header"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            req.add_header(key, value)

        req.add_header("Cookie", f"{credentials.SSO_TOKEN_KEY}={credentials.SESSION_TOKEN}")
        req.add_header(credentials.SSO_TOKEN_KEY, credentials.SESSION_TOKEN)
        req.add_header("x-adapter-source", self._effective_adapter_source())
        req.add_header("x-adapter-email", credentials.USER_EMAIL)
        req.add_header("X-Adapter-User-Email", credentials.USER_EMAIL)
        req.add_header("x-adapter-scenario", "codewiz-opencode-cli")

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        forward(handler, req, body_json, model, n, session_id, conversation_id, False)
