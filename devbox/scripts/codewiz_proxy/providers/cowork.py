from __future__ import annotations

import base64
import json
import ssl
import time
import urllib.error
import urllib.request

from .. import config
from ..utils import log, rewrite_body, strip_thinking_blocks
from ..telemetry import SESSION
from .base import BaseProvider

# Cowork 直连，不走本机 https_proxy：
# 1. 强制 HTTP/1.1（urllib 不支持 HTTP/2，服务端 ALPN 协商 h2 会挂死）
# 2. 使用无代理 opener（绕过 HTTPS_PROXY 环境变量）
_SSL_CTX = ssl.create_default_context()
_SSL_CTX.set_alpn_protocols(["http/1.1"])
_OPENER = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=_SSL_CTX),
)


def _make_req(url: str, body: bytes, token: str) -> urllib.request.Request:
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    return req


def _to_bedrock_body(body_json: dict) -> bytes:
    """Anthropic Messages body → Bedrock invoke body（去掉 model，加 anthropic_version）"""
    bd = dict(body_json)  # shallow copy — do NOT mutate nested lists (messages, system)
    bd.pop("model", None)
    bd.pop("stream", None)
    bd["anthropic_version"] = "bedrock-2023-05-31"
    return json.dumps(bd).encode("utf-8")


class CoworkProvider(BaseProvider):

    def _check_api_key(self, handler) -> bool:
        if not config.COWORK_API_KEY:
            handler.send_response(503)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({"error": "COWORK_API_KEY 未设置"}).encode())
            return False
        return True

    def handle_anthropic(
        self,
        handler,
        body: bytes,
        provider_registry: "dict | None" = None,
    ) -> None:
        if not self._check_api_key(handler):
            return

        r = rewrite_body(body)
        for info in r.logs:
            log(f"  [cowork/rewrite] {info}")
        body_json = r.body_json

        # Bedrock 的 thinking block signature 严格 session 绑定，历史消息中的必须剥离
        strip_thinking_blocks(body_json)

        original_model = body_json.get("model", "")
        body_json["model"] = config.COWORK_MODEL
        if original_model and original_model != config.COWORK_MODEL:
            log(f"  [cowork] model: {original_model} -> {config.COWORK_MODEL}")

        is_stream = body_json.get("stream", False)
        log(f"  [cowork] stream: {is_stream}  messages: {len(body_json.get('messages', []))} 条")
        if config.VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        bedrock_body = _to_bedrock_body(body_json)

        if is_stream:
            url = f"{config.COWORK_BASE_URL}/model/{config.COWORK_MODEL}/invoke-with-response-stream"
            req = _make_req(url, bedrock_body, config.COWORK_API_KEY)
            self._forward_stream(handler, req)
        else:
            url = f"{config.COWORK_BASE_URL}/model/{config.COWORK_MODEL}/invoke"
            req = _make_req(url, bedrock_body, config.COWORK_API_KEY)
            SESSION.bump_and_snapshot()
            self._forward_non_stream(handler, req)

    def _forward_non_stream(self, handler, req: urllib.request.Request) -> None:
        start_time = time.time()
        try:
            resp = _OPENER.open(req, timeout=600)
            elapsed = time.time() - start_time
            log(f"  [cowork] 响应 {resp.status} ({elapsed:.1f}s)")
            body = resp.read()
            handler.send_response(resp.status)
            for key, value in resp.getheaders():
                if key.lower() not in ("transfer-encoding", "connection"):
                    handler.send_header(key, value)
            handler.end_headers()
            handler.wfile.write(body)
        except urllib.error.HTTPError as e:
            elapsed = time.time() - start_time
            error_body = e.read()
            log(f"  [cowork] 错误 {e.code} ({elapsed:.1f}s): {repr(error_body[:300])}")
            handler.send_response(e.code)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(error_body)
        except Exception as e:
            elapsed = time.time() - start_time
            log(f"  [cowork] 异常 ({elapsed:.1f}s): {e}")
            handler.send_response(502)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({"error": str(e)}).encode())

    def handle_openai(
        self,
        handler,
        body: bytes,
        provider_registry: "dict | None" = None,
    ) -> None:
        # cowork 只暴露 Anthropic 路径，openai 路径不支持
        handler.send_response(501)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(json.dumps({"error": "cowork provider does not support OpenAI path"}).encode())

    def _forward_stream(self, handler, req: urllib.request.Request) -> None:
        """
        Bedrock streaming 响应格式：每行一个 JSON
          {"chunk":{"bytes":"<base64(Anthropic SSE event JSON)>"},...}
        转换成标准 Anthropic SSE 流返回给 Claude Code。
        """
        try:
            resp = _OPENER.open(req, timeout=600)
        except urllib.error.HTTPError as e:
            error_body = e.read()
            log(f"  [cowork] 错误 {e.code}: {repr(error_body[:300])}")
            handler.send_response(e.code)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(error_body)
            return
        except Exception as e:
            log(f"  [cowork] 异常: {e}")
            handler.send_response(502)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({"error": str(e)}).encode())
            return

        log(f"  [cowork] 响应 {resp.status} (stream)")
        handler.send_response(200)
        handler.send_header("Content-Type", "text/event-stream")
        handler.send_header("Cache-Control", "no-cache")
        handler.end_headers()

        buf = b""
        got_message_stop = False
        try:
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        envelope = json.loads(line)
                    except (json.JSONDecodeError, ValueError):
                        if config.VERBOSE:
                            log(f"  [cowork] 跳过无效行: {line[:100]}")
                        continue
                    b64 = envelope.get("chunk", {}).get("bytes", "")
                    if not b64:
                        continue
                    try:
                        event_json = base64.b64decode(b64).decode("utf-8")
                    except Exception:
                        continue
                    try:
                        event = json.loads(event_json)
                        event_type = event.get("type", "")
                    except (json.JSONDecodeError, ValueError):
                        if config.VERBOSE:
                            log(f"  [cowork] 跳过无效 event: {event_json[:100]}")
                        continue
                    if event_type == "message_stop":
                        got_message_stop = True
                    sse_line = f"event: {event_type}\ndata: {event_json}\n\n".encode("utf-8")
                    handler.wfile.write(sse_line)
                    handler.wfile.flush()
        except Exception as e:
            log(f"  [cowork] 流读取异常: {e}")

        if not got_message_stop:
            handler.wfile.write(b"event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n")
            handler.wfile.flush()
