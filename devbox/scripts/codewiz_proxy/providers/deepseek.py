from __future__ import annotations

import json
import urllib.request

from .. import config
from ..utils import log, rewrite_body, filter_beta_header, strip_thinking_blocks
from ..telemetry import SESSION
from ..convert import convert_responses_to_chat
from ..forward import forward, forward_responses
from .base import BaseProvider


class DeepseekProvider(BaseProvider):
    def _check_api_key(self, handler) -> bool:
        if not config.DEEPSEEK_API_KEY:
            handler.send_response(503)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({"error": "DEEPSEEK_API_KEY 未设置"}).encode())
            return False
        return True

    def handle_anthropic(self, handler, body: bytes) -> None:
        if not self._check_api_key(handler):
            return

        body, body_json, _extra, rewrite_logs, _ = rewrite_body(body)
        rewrite_logs.extend(strip_thinking_blocks(body_json))
        for info in rewrite_logs:
            log(f"  [deepseek/rewrite] {info}")

        original_model = body_json.get("model", "")
        if original_model != config.DEEPSEEK_MODEL:
            body_json["model"] = config.DEEPSEEK_MODEL
            log(f"  [deepseek] model: {original_model} -> {config.DEEPSEEK_MODEL}")
            body = json.dumps(body_json).encode("utf-8")

        log(f"  [deepseek] stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")

        target_url = config.DEEPSEEK_ANTHROPIC_BASE_URL + handler.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-api-key"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            if key.lower() == "anthropic-beta":
                filtered = filter_beta_header(value)
                if filtered:
                    req.add_header(key, filtered)
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {config.DEEPSEEK_API_KEY}")

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        forward(handler, req, body_json, config.DEEPSEEK_MODEL, n, session_id, conversation_id, False)

    def handle_openai(self, handler, body: bytes) -> None:
        if not self._check_api_key(handler):
            return

        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        is_responses = handler.path.startswith("/responses")
        if is_responses:
            body_json = convert_responses_to_chat(body_json, default_model=config.DEEPSEEK_MODEL)
            target_path = "/v1/chat/completions"
        else:
            target_path = handler.path

        original_model = body_json.get("model", "")
        if original_model != config.DEEPSEEK_MODEL:
            body_json["model"] = config.DEEPSEEK_MODEL
            log(f"  [deepseek/openai] model: {original_model} -> {config.DEEPSEEK_MODEL}")

        body = json.dumps(body_json).encode("utf-8")
        log(f"  [deepseek/openai] path: {target_path}  stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")

        target_url = config.DEEPSEEK_OPENAI_BASE_URL + target_path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-anthropic-billing-header"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {config.DEEPSEEK_API_KEY}")

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        if is_responses:
            forward_responses(handler, req, config.DEEPSEEK_MODEL)
        else:
            forward(handler, req, body_json, config.DEEPSEEK_MODEL, n, session_id, conversation_id, False)
