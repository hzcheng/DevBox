from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
import uuid

from . import config
from .utils import log, extract_usage
from .telemetry import SESSION, fire_fake_session


def forward(handler, req: urllib.request.Request, body_json: dict,
            model_id: str | None, n: int,
            session_id: str, conversation_id: str, should_report: bool) -> None:
    """统一 HTTP 转发：流式写回响应，按需触发遥测"""
    start_time = time.time()
    try:
        resp = urllib.request.urlopen(req, context=config._SSL_CTX, timeout=600)
        elapsed = time.time() - start_time
        log(f"响应 {resp.status} ({elapsed:.1f}s)")

        handler.send_response(resp.status)
        for key, value in resp.getheaders():
            if key.lower() not in ("transfer-encoding", "connection"):
                handler.send_header(key, value)
        handler.end_headers()

        collected = bytearray()
        while True:
            chunk = resp.read(4096)
            if not chunk:
                break
            handler.wfile.write(chunk)
            handler.wfile.flush()
            if should_report:
                collected.extend(chunk)

        if should_report and collected:
            input_tokens, output_tokens, cache_read, cache_write = extract_usage(bytes(collected))
            if input_tokens > 0 or output_tokens > 0:
                log(f"  [metrics] #{n}: in={input_tokens} out={output_tokens}")
                threading.Thread(
                    target=fire_fake_session,
                    args=(model_id, session_id, conversation_id,
                          input_tokens, output_tokens, cache_read, cache_write),
                    daemon=True,
                ).start()

    except urllib.error.HTTPError as e:
        elapsed = time.time() - start_time
        error_body = e.read()
        log(f"错误 {e.code} ({elapsed:.1f}s): {repr(error_body[:300])}")
        dump_path = os.path.expanduser(
            f"~/.cache/claude_proxy/codewiz_failed_{int(time.time())}_{uuid.uuid4().hex[:8]}.json"
        )
        os.makedirs(os.path.dirname(dump_path), exist_ok=True)
        try:
            with open(dump_path, "w", encoding="utf-8") as f:
                json.dump(body_json, f, ensure_ascii=False, indent=2)
            log(f"  body dumped to: {dump_path}")
        except Exception as dump_err:
            log(f"  dump failed: {dump_err}")
        else:
            try:
                os.chmod(dump_path, 0o600)
            except OSError:
                pass
        handler.send_response(e.code)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(error_body)

    except Exception as e:
        elapsed = time.time() - start_time
        log(f"异常 ({elapsed:.1f}s): {e}")
        handler.send_response(502)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(json.dumps({"error": str(e)}).encode())


def forward_responses(handler, req: urllib.request.Request, model: str) -> None:
    """把 chat.completion.chunk SSE 流转成 OpenAI Responses API SSE 流"""
    start_time = time.time()
    try:
        resp = urllib.request.urlopen(req, context=config._SSL_CTX, timeout=600)
        elapsed = time.time() - start_time
        log(f"响应 {resp.status} ({elapsed:.1f}s) [responses转换]")
    except urllib.error.HTTPError as e:
        elapsed = time.time() - start_time
        error_body = e.read()
        log(f"错误 {e.code} ({elapsed:.1f}s): {repr(error_body[:300])}")
        handler.send_response(e.code)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(error_body)
        return
    except Exception as e:
        elapsed = time.time() - start_time
        log(f"异常 ({elapsed:.1f}s): {e}")
        handler.send_response(502)
        handler.send_header("Content-Type", "application/json")
        handler.end_headers()
        handler.wfile.write(json.dumps({"error": str(e)}).encode())
        return

    resp_id = f"resp_{uuid.uuid4().hex}"
    created_at = int(time.time())
    seq = 0

    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream")
    handler.send_header("Cache-Control", "no-cache")
    handler.end_headers()

    def sse(event, data):
        data["sequence_number"] = seq
        return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n".encode()

    def send(event, data):
        nonlocal seq
        handler.wfile.write(sse(event, data))
        handler.wfile.flush()
        seq += 1

    base_resp = {
        "id": resp_id, "object": "response", "created_at": created_at,
        "status": "in_progress", "model": model, "output": [], "usage": None,
    }
    send("response.created", {"type": "response.created", "response": dict(base_resp)})
    send("response.in_progress", {"type": "response.in_progress", "response": dict(base_resp)})

    full_text = []
    tool_calls_buf = {}
    msg_item_id = f"msg_{uuid.uuid4().hex}"
    text_item_started = False
    # output_index 在 Responses API 中是全局递增的；文本占 0，function call 从 1 开始
    next_output_index = 1

    buf = b""
    usage_info = None
    stream_done = False
    try:
        for chunk in resp:
            if stream_done:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line.startswith(b"data:"):
                    continue
                payload = line[5:].strip()
                if payload == b"[DONE]":
                    stream_done = True
                    break
                try:
                    cj = json.loads(payload)
                except (json.JSONDecodeError, ValueError):
                    continue
                # 提取 usage（Chat Completions SSE 末尾的 usage chunk，choices 为空）
                u = cj.get("usage")
                if isinstance(u, dict) and u:
                    usage_info = {
                        "input_tokens": u.get("prompt_tokens", 0),
                        "output_tokens": u.get("completion_tokens", 0),
                        "total_tokens": u.get("total_tokens", 0),
                    }
                    continue
                choices = cj.get("choices", [])
                if not choices:
                    continue
                delta = choices[0].get("delta", {})

                text = delta.get("content")
                if text is None:
                    text = delta.get("reasoning_content") or ""
                if text:
                    if not text_item_started:
                        text_item_started = True
                        send("response.output_item.added", {
                            "type": "response.output_item.added", "output_index": 0,
                            "item": {"id": msg_item_id, "type": "message", "status": "in_progress",
                                     "role": "assistant", "content": []},
                        })
                        send("response.content_part.added", {
                            "type": "response.content_part.added",
                            "output_index": 0, "content_index": 0, "item_id": msg_item_id,
                            "part": {"type": "output_text", "text": "", "annotations": []},
                        })
                    full_text.append(text)
                    send("response.output_text.delta", {
                        "type": "response.output_text.delta",
                        "output_index": 0, "content_index": 0,
                        "item_id": msg_item_id, "delta": text,
                    })

                for tc in (delta.get("tool_calls") or []):
                    idx = tc.get("index", 0)
                    if idx not in tool_calls_buf:
                        tc_item_id = f"fc_{uuid.uuid4().hex}"
                        call_id = tc.get("id", f"call_{uuid.uuid4().hex[:8]}")
                        output_index = next_output_index
                        next_output_index += 1
                        tool_calls_buf[idx] = {
                            "id": call_id, "item_id": tc_item_id, "name": "", "args": "",
                            "output_index": output_index,
                        }
                        send("response.output_item.added", {
                            "type": "response.output_item.added", "output_index": output_index,
                            "item": {"id": tc_item_id, "type": "function_call",
                                     "status": "in_progress", "call_id": call_id,
                                     "name": "", "arguments": ""},
                        })
                    entry = tool_calls_buf[idx]
                    fn = tc.get("function", {})
                    if fn.get("name"):
                        entry["name"] = fn["name"]
                    args_delta = fn.get("arguments", "")
                    if args_delta:
                        entry["args"] += args_delta
                        send("response.function_call_arguments.delta", {
                            "type": "response.function_call_arguments.delta",
                            "output_index": entry["output_index"], "item_id": entry["item_id"],
                            "delta": args_delta,
                        })
    except Exception as e:
        log(f"  [responses转换] 流读取异常: {e}")

    output_items = []
    if text_item_started:
        text_done = "".join(full_text)
        send("response.output_text.done", {
            "type": "response.output_text.done",
            "output_index": 0, "content_index": 0,
            "item_id": msg_item_id, "text": text_done,
        })
        send("response.content_part.done", {
            "type": "response.content_part.done",
            "output_index": 0, "content_index": 0, "item_id": msg_item_id,
            "part": {"type": "output_text", "text": text_done, "annotations": []},
        })
        msg_item = {"id": msg_item_id, "type": "message", "status": "completed",
                    "role": "assistant",
                    "content": [{"type": "output_text", "text": text_done, "annotations": []}]}
        send("response.output_item.done", {
            "type": "response.output_item.done", "output_index": 0, "item": msg_item,
        })
        output_items.append(msg_item)

    for idx in sorted(tool_calls_buf):
        entry = tool_calls_buf[idx]
        send("response.function_call_arguments.done", {
            "type": "response.function_call_arguments.done",
            "output_index": entry["output_index"], "item_id": entry["item_id"],
            "arguments": entry["args"],
        })
        fc_item = {"id": entry["item_id"], "type": "function_call", "status": "completed",
                   "call_id": entry["id"], "name": entry["name"], "arguments": entry["args"]}
        send("response.output_item.done", {
            "type": "response.output_item.done", "output_index": entry["output_index"], "item": fc_item,
        })
        output_items.append(fc_item)

    send("response.completed", {
        "type": "response.completed",
        "response": {**base_resp, "status": "completed", "output": output_items, "usage": usage_info},
    })
