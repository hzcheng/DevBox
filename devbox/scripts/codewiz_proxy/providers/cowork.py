from __future__ import annotations

import base64
import json
import ssl
import struct
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

    # ── EventStream 解析工具 ──
    @staticmethod
    def _parse_eventstream_message(buf: bytes):
        """解析单个 Amazon EventStream 消息。
        返回 (event_type: str, payload: bytes, is_exception: bool, bytes_consumed: int)
        或 None（数据不足）"""
        if len(buf) < 12:
            return None

        total_len = struct.unpack(">I", buf[:4])[0]
        headers_len = struct.unpack(">I", buf[4:8])[0]

        if total_len < 12 or headers_len > total_len - 12:
            return None
        if len(buf) < total_len:
            return None

        headers_data = buf[12:12 + headers_len]
        payload = buf[12 + headers_len:total_len - 4]

        pos = 0
        event_type = None
        message_type = None

        while pos < len(headers_data):
            key_len = headers_data[pos]
            pos += 1
            key = headers_data[pos:pos + key_len].decode("utf-8")
            pos += key_len
            value_type = headers_data[pos]
            pos += 1

            if value_type == 0:
                value = True
            elif value_type == 1:
                value = False
            elif value_type == 7:  # string
                if pos + 2 > len(headers_data):
                    break
                value_len = struct.unpack(">H", headers_data[pos:pos + 2])[0]
                pos += 2
                if pos + value_len > len(headers_data):
                    break
                value = headers_data[pos:pos + value_len].decode("utf-8")
                pos += value_len
            else:
                # 不支持的 header value 类型，停止解析 headers
                break

            if key == ":event-type":
                event_type = value
            elif key == ":message-type":
                message_type = value

        is_exception = message_type == "exception"
        return event_type, payload, is_exception, total_len

    def _forward_stream(self, handler, req: urllib.request.Request) -> None:
        """
        Bedrock streaming 响应格式：
          旧：每行一个 JSON  {"chunk":{"bytes":"<base64>"},...}
          新：Amazon EventStream 二进制格式（Content-Type: application/vnd.amazon.eventstream）
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

        content_type = resp.getheader("Content-Type", "")
        log(f"  [cowork] Content-Type: {content_type}")
        if "eventstream" in content_type:
            self._forward_eventstream(handler, resp)
        else:
            self._forward_ndjson_stream(handler, resp)

    def _forward_eventstream(self, handler, resp) -> None:
        """解析 Amazon EventStream 二进制流并转换为 Anthropic SSE。"""
        buf = b""
        got_message_stop = False
        exception_payload = None

        while True:
            chunk = resp.read(4096)
            if not chunk:
                break
            buf += chunk

            while True:
                result = self._parse_eventstream_message(buf)
                if result is None:
                    break
                event_type, payload, is_exception, consumed = result
                buf = buf[consumed:]

                if is_exception:
                    exception_payload = payload
                    log(f"  [cowork] EventStream exception: {payload[:200]}")
                    continue

                if event_type != "chunk":
                    continue

                try:
                    envelope = json.loads(payload)
                except (json.JSONDecodeError, ValueError):
                    continue

                b64 = envelope.get("chunk", {}).get("bytes", "")
                if not b64:
                    b64 = envelope.get("bytes", "")
                if not b64:
                    continue
                if not b64:
                    continue

                try:
                    event_json = base64.b64decode(b64).decode("utf-8")
                except Exception:
                    continue

                try:
                    event = json.loads(event_json)
                    etype = event.get("type", "")
                except (json.JSONDecodeError, ValueError):
                    continue

                if etype == "message_stop":
                    got_message_stop = True
                sse_line = f"event: {etype}\ndata: {event_json}\n\n".encode("utf-8")
                handler.wfile.write(sse_line)
                handler.wfile.flush()

        if exception_payload:
            try:
                err = json.loads(exception_payload)
                err_msg = err.get("message", "Bedrock streaming error")
            except Exception:
                err_msg = exception_payload.decode("utf-8", errors="replace")[:200]
            handler.wfile.write(
                f'event: error\ndata: {json.dumps({"type": "error", "error": {"type": "api_error", "message": err_msg}})}\n\n'.encode()
            )
            handler.wfile.flush()
            return

        if not got_message_stop:
            handler.wfile.write(b'event: message_stop\ndata: {"type":"message_stop"}\n\n')
            handler.wfile.flush()

    def _forward_ndjson_stream(self, handler, resp) -> None:
        """旧版 NDJSON 流（每行一个 JSON 对象）。"""
        buf = b""
        got_message_stop = False

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
                    b64 = envelope.get("bytes", "")
                if not b64:
                    continue
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

        if not got_message_stop:
            handler.wfile.write(b'event: message_stop\ndata: {"type":"message_stop"}\n\n')
            handler.wfile.flush()
