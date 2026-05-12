from __future__ import annotations

import json
import os
import threading
import time
import urllib.request

from .. import config
from ..utils import log, rewrite_body, filter_beta_header, strip_thinking_blocks
from ..telemetry import SESSION
from ..convert import convert_responses_to_chat
from ..forward import forward, forward_responses
from .base import BaseProvider

_KIMI_LOCK = threading.Lock()
_KIMI_ACCESS_TOKEN: str = ""
_KIMI_REFRESH_TOKEN: str = ""
_KIMI_EXPIRES_AT: float = 0.0


def _load_kimi_credentials_from_file() -> tuple[str, str, float] | None:
    try:
        with open(config.KIMI_CREDENTIALS_PATH) as f:
            data = json.load(f)
        return data["access_token"], data["refresh_token"], float(data["expires_at"])
    except (OSError, KeyError, ValueError):
        return None


def _refresh_kimi_token(refresh_token: str) -> tuple[str, str, float] | None:
    import urllib.parse
    payload = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": "17e5f671-d194-4dfb-9706-5516cb48c098",
    }).encode()
    try:
        req = urllib.request.Request(config.KIMI_OAUTH_TOKEN_URL, data=payload, method="POST")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
        req.add_header("User-Agent", config.KIMI_USER_AGENT)
        resp = urllib.request.urlopen(req, context=config._SSL_CTX, timeout=15)
        data = json.loads(resp.read())
        expires_at = time.time() + float(data["expires_in"])
        return data["access_token"], data.get("refresh_token", refresh_token), expires_at
    except Exception as e:
        log(f"[kimi] token 刷新失败: {e}")
        return None


def get_kimi_token() -> str:
    global _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT
    with _KIMI_LOCK:
        if _KIMI_ACCESS_TOKEN and time.time() < _KIMI_EXPIRES_AT - 60:
            return _KIMI_ACCESS_TOKEN

        creds = _load_kimi_credentials_from_file()
        if creds:
            access, refresh, expires_at = creds
            if time.time() < expires_at - 60:
                _KIMI_ACCESS_TOKEN = access
                _KIMI_REFRESH_TOKEN = refresh
                _KIMI_EXPIRES_AT = expires_at
                log("[kimi] 从凭据文件加载 token")
                return _KIMI_ACCESS_TOKEN
            _KIMI_REFRESH_TOKEN = refresh

        if not _KIMI_REFRESH_TOKEN:
            raise RuntimeError("Kimi 未登录，请先运行 kimi-cli 完成登录")

        result = _refresh_kimi_token(_KIMI_REFRESH_TOKEN)
        if not result:
            raise RuntimeError("Kimi token 刷新失败")

        _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT = result
        try:
            with open(config.KIMI_CREDENTIALS_PATH, "w") as f:
                json.dump({
                    "access_token": _KIMI_ACCESS_TOKEN,
                    "refresh_token": _KIMI_REFRESH_TOKEN,
                    "expires_at": _KIMI_EXPIRES_AT,
                    "scope": "kimi-code",
                    "token_type": "Bearer",
                    "expires_in": _KIMI_EXPIRES_AT - time.time(),
                }, f)
            os.chmod(config.KIMI_CREDENTIALS_PATH, 0o600)
            log("[kimi] token 已刷新并写回凭据文件")
        except OSError:
            pass

        return _KIMI_ACCESS_TOKEN



def get_token_ttl() -> int:
    with _KIMI_LOCK:
        return max(0, int(_KIMI_EXPIRES_AT - time.time()))


class KimiProvider(BaseProvider):
    def _get_token_or_error(self, handler) -> str | None:
        try:
            return get_kimi_token()
        except RuntimeError as e:
            log(f"  [kimi] 获取 token 失败: {e}")
            handler.send_response(503)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({"error": str(e)}).encode())
            return None

    def handle_anthropic(self, handler, body: bytes) -> None:
        body, body_json, _extra, rewrite_logs, _ = rewrite_body(body)
        rewrite_logs.extend(strip_thinking_blocks(body_json))
        for info in rewrite_logs:
            log(f"  [kimi/rewrite] {info}")

        original_model = body_json.get("model", "")
        if original_model != config.KIMI_MODEL:
            body_json["model"] = config.KIMI_MODEL
            log(f"  [kimi] model: {original_model} -> {config.KIMI_MODEL}")
            body = json.dumps(body_json).encode("utf-8")

        log(f"  [kimi] stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")
        if config.VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        token = self._get_token_or_error(handler)
        if token is None:
            return

        target_url = config.KIMI_TARGET_BASE_URL + handler.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "anthropic-version", "x-api-key"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            if key.lower() == "anthropic-beta":
                filtered = filter_beta_header(value)
                if filtered:
                    req.add_header(key, filtered)
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("User-Agent", config.KIMI_USER_AGENT)

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        forward(handler, req, body_json, config.KIMI_MODEL, n, session_id, conversation_id, False)

    def handle_openai(self, handler, body: bytes) -> None:
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        is_responses = handler.path.startswith("/responses")
        if is_responses:
            body_json = convert_responses_to_chat(body_json, default_model=config.KIMI_MODEL)
            target_path = "/v1/chat/completions"
        else:
            target_path = handler.path

        original_model = body_json.get("model", "")
        if original_model != config.KIMI_MODEL:
            body_json["model"] = config.KIMI_MODEL
            log(f"  [kimi/openai] model: {original_model} -> {config.KIMI_MODEL}")

        body = json.dumps(body_json).encode("utf-8")
        log(f"  [kimi/openai] path: {target_path}  stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")
        if config.VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        token = self._get_token_or_error(handler)
        if token is None:
            return

        target_url = config.KIMI_TARGET_BASE_URL + target_path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-anthropic-billing-header"}
        for key, value in handler.headers.items():
            if key.lower() in skip_headers:
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("User-Agent", config.KIMI_USER_AGENT)

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        if is_responses:
            forward_responses(handler, req, config.KIMI_MODEL)
        else:
            forward(handler, req, body_json, config.KIMI_MODEL, n, session_id, conversation_id, False)
