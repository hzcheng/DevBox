from __future__ import annotations

import json
from datetime import datetime

from . import config


def log(msg: str) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    if config.LOG_FILE:
        config.LOG_FILE.write(line + "\n")
        config.LOG_FILE.flush()


def filter_beta_header(value: str) -> str | None:
    betas = [b.strip() for b in value.split(",") if b.strip()]
    filtered = [b for b in betas if any(b.startswith(p) for p in config.ALLOWED_BETA_PREFIXES)]
    return ", ".join(filtered) if filtered else None


def extract_billing_header(body_json: dict) -> tuple[str | None, list[str]]:
    """
    Claude Code v2.1+ 将 x-anthropic-billing-header 放在 system 数组第一个 block 的文本里。
    返回 (billing_header_value_or_None, logs)
    """
    system = body_json.get("system")
    if not isinstance(system, list) or not system:
        return None, []
    first = system[0]
    if not isinstance(first, dict):
        return None, []
    text = first.get("text", "")
    prefix = "x-anthropic-billing-header:"
    if not text.startswith(prefix):
        return None, []
    value = text[len(prefix):].strip()
    body_json["system"] = system[1:]
    if not body_json["system"]:
        del body_json["system"]
    return value, [f"extracted billing header: {value[:60]}"]


def _strip_cache_control_scope(obj) -> None:
    """递归删除所有 cache_control 对象中的 scope 字段"""
    if isinstance(obj, dict):
        if "cache_control" in obj and isinstance(obj["cache_control"], dict):
            obj["cache_control"].pop("scope", None)
        for v in obj.values():
            _strip_cache_control_scope(v)
    elif isinstance(obj, list):
        for item in obj:
            _strip_cache_control_scope(item)


def strip_thinking_blocks(body_json: dict) -> list[str]:
    """从 messages 历史中移除所有 thinking/redacted_thinking content blocks，返回日志。
    Bedrock 的 thinking block signature 与 session 绑定，resume 时历史里的 signature 全部失效。"""
    logs = []
    messages = body_json.get("messages")
    if not isinstance(messages, list):
        return logs
    for msg in messages:
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        filtered = [
            block for block in content
            if not (isinstance(block, dict) and block.get("type") in ("thinking", "redacted_thinking"))
        ]
        if len(filtered) != len(content):
            removed = len(content) - len(filtered)
            logs.append(f"stripped {removed} thinking block(s) from {msg.get('role', '?')} message")
            msg["content"] = filtered
    return logs


def rewrite_body(body_bytes: bytes) -> tuple[bytes, dict, dict, list, str | None]:
    """模型映射 + 剥离不支持的字段，返回 (new_body, body_json, extra_headers, logs, model_id)"""
    try:
        body_json = json.loads(body_bytes)
    except (json.JSONDecodeError, ValueError):
        return body_bytes, {}, {}, [], None

    logs = []
    extra_headers = {}
    model_id = None

    original_model = body_json.get("model", "")
    if original_model in config.MODEL_MAP:
        mapped = config.MODEL_MAP[original_model]
        logs.append(f"model: {original_model} -> {mapped}")
        model_id = mapped
        body_json["model"] = mapped
    elif original_model:
        model_id = original_model

    for key in config.STRIP_FIELDS:
        if key in body_json:
            del body_json[key]
            logs.append(f"stripped: {key}")

    logs.extend(strip_thinking_blocks(body_json))

    billing_val, billing_logs = extract_billing_header(body_json)
    logs.extend(billing_logs)
    if billing_val:
        extra_headers["x-anthropic-billing-header"] = billing_val

    _strip_cache_control_scope(body_json)

    return json.dumps(body_json).encode("utf-8"), body_json, extra_headers, logs, model_id


def extract_usage(data: bytes) -> tuple[int, int, int, int]:
    """从 SSE 或 JSON 响应中提取 token 用量"""
    text = data.decode("utf-8", errors="replace")
    input_tokens = output_tokens = cache_read = cache_write = 0

    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        try:
            v = json.loads(line[5:].strip())
        except (json.JSONDecodeError, ValueError):
            continue
        msg = v.get("message")
        if isinstance(msg, dict):
            u = msg.get("usage")
            if isinstance(u, dict):
                input_tokens = u.get("input_tokens", input_tokens)
                cache_read = u.get("cache_read_input_tokens", cache_read)
                cache_write = u.get("cache_creation_input_tokens", cache_write)
        u = v.get("usage")
        if isinstance(u, dict):
            output_tokens = u.get("output_tokens", output_tokens)

    if input_tokens == 0 and output_tokens == 0:
        try:
            v = json.loads(data)
            u = v.get("usage", {})
            input_tokens = u.get("input_tokens", 0)
            output_tokens = u.get("output_tokens", 0)
            cache_read = u.get("cache_read_input_tokens", 0)
            cache_write = u.get("cache_creation_input_tokens", 0)
        except (json.JSONDecodeError, ValueError):
            pass

    return input_tokens, output_tokens, cache_read, cache_write
