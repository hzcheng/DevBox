from __future__ import annotations

import json
import urllib.request

from .. import config, credentials
from ..utils import log, rewrite_body, filter_beta_header
from ..telemetry import SESSION
from ..forward import forward, forward_responses
from .base import BaseProvider


def _convert_responses_to_chat(body_json: dict) -> dict:
    """把 OpenAI Responses API 请求体转成 Chat Completions API 请求体。"""
    chat: dict = {}

    # 基本字段直接透传
    for key in ("model", "temperature", "top_p", "stream", "metadata", "user", "parallel_tool_calls"):
        if key in body_json:
            chat[key] = body_json[key]

    # input -> messages（只保留 role 和 content，移除 Responses API 特有的 type 等字段）
    _RESPONSES_CONTENT_TYPE_MAP = {
        "input_text": "text",
        "input_image": "image_url",
        "output_text": "text",
        "output_image": "image_url",
        "refusal": "text",
    }

    def _norm_content(content):
        """把 Responses API 的 content parts 转成 Chat Completions 格式。"""
        if isinstance(content, list):
            new_parts = []
            for part in content:
                if isinstance(part, dict):
                    new_part: dict = {}
                    old_type = part.get("type")
                    new_type = _RESPONSES_CONTENT_TYPE_MAP.get(old_type, old_type)
                    new_part["type"] = new_type
                    if "text" in part:
                        new_part["text"] = part["text"]
                    # refusal 内容放到 text 字段中
                    if old_type == "refusal" and "refusal" in part:
                        new_part["text"] = part["refusal"]
                    # image_url: Responses API 可能是字符串，Chat Completions 需要对象
                    if "image_url" in part:
                        image_url_val = part["image_url"]
                        if isinstance(image_url_val, str):
                            new_part["image_url"] = {"url": image_url_val}
                            if "detail" in part:
                                new_part["image_url"]["detail"] = part["detail"]
                        elif isinstance(image_url_val, dict):
                            new_part["image_url"] = image_url_val
                    new_parts.append(new_part)
                else:
                    new_parts.append(part)
            return new_parts
        return content

    def _norm_msg(m) -> dict | None:
        """把 Responses API 的 message 对象转成 Chat Completions 格式。"""
        if not isinstance(m, dict):
            return None

        # ── function_call_output → Chat Completions tool message ──
        if m.get("type") == "function_call_output":
            return {
                "role": "tool",
                "tool_call_id": m.get("call_id", ""),
                "content": m.get("output", "") or "",
            }

        role = m.get("role")
        content = m.get("content")
        if role is None:
            return None
        if role == "developer":
            role = "system"
        if content is None:
            content = ""

        msg: dict = {"role": role, "content": _norm_content(content)}

        # ── 保留顶层 tool_calls（部分 Responses API 消息直接使用此字段）──
        if role == "assistant" and "tool_calls" in m:
            msg["tool_calls"] = m["tool_calls"]

        # ── content 数组中包含 function_call 对象时，提取为 tool_calls ──
        # Responses API 的 assistant message 常在 content 里用
        # {"type":"function_call","id":"...","call_id":"...","name":"...","arguments":"..."}
        if role == "assistant" and isinstance(content, list):
            extracted_tool_calls = []
            filtered_content = []
            for part in content:
                if isinstance(part, dict) and part.get("type") == "function_call":
                    extracted_tool_calls.append({
                        "id": part.get("id") or part.get("call_id", ""),
                        "type": "function",
                        "function": {
                            "name": part.get("name", ""),
                            "arguments": part.get("arguments", ""),
                        },
                    })
                else:
                    filtered_content.append(part)
            if extracted_tool_calls:
                msg["tool_calls"] = extracted_tool_calls
                # Chat Completions 的 content 中不能保留 function_call 对象
                msg["content"] = _norm_content(filtered_content) if filtered_content else ""

        if role == "tool":
            if "tool_call_id" in m:
                msg["tool_call_id"] = m["tool_call_id"]
            if "name" in m:
                msg["name"] = m["name"]

        return msg

    inp = body_json.get("input")
    messages: list[dict] = []
    if isinstance(inp, list):
        for m in inp:
            nm = _norm_msg(m)
            if nm is not None:
                messages.append(nm)
    elif isinstance(inp, str):
        messages = [{"role": "user", "content": inp}]

    # instructions -> system message前置
    instructions = body_json.get("instructions")
    if instructions:
        if isinstance(instructions, str):
            messages.insert(0, {"role": "system", "content": instructions})
        elif isinstance(instructions, list):
            # instructions 是 content parts 数组时也需要规范化
            messages.insert(0, {"role": "system", "content": _norm_content(instructions)})

    if messages:
        chat["messages"] = messages

    # max_output_tokens -> max_tokens
    if "max_output_tokens" in body_json:
        chat["max_tokens"] = body_json["max_output_tokens"]

    # tools: Responses API 的 function/custom tool 顶层字段需包裹到嵌套对象中
    # function: {"type":"function","name":"..."} → {"type":"function","function":{"name":"..."}}
    # custom:   {"type":"custom","name":"..."}   → {"type":"function","function":{"name":"..."}}
    #   （Chat Completions 不支持 custom，统一映射为 function）
    # web_search 等后端不支持的类型直接丢弃
    _SUPPORTED_TOOL_TYPES = ("function", "custom")
    tools = body_json.get("tools")
    if isinstance(tools, list):
        chat_tools = []
        for tool in tools:
            if isinstance(tool, dict):
                ttype = tool.get("type")
                if ttype not in _SUPPORTED_TOOL_TYPES:
                    log(f"  [responses→chat] dropping unsupported tool type: {ttype}")
                    continue
                # Chat Completions 只支持 function 类型
                normalized_type = "function"
                nested = {}
                for k in ("name", "description", "parameters", "strict"):
                    if k in tool:
                        nested[k] = tool[k]
                chat_tools.append({"type": normalized_type, normalized_type: nested})
            else:
                chat_tools.append(tool)
        chat["tools"] = chat_tools

    # tool_choice: Responses API 格式 {"type":"function","name":"..."} / {"type":"custom","name":"..."}
    # 需转成 Chat Completions 格式 {"type":"function","function":{"name":"..."}}
    tool_choice = body_json.get("tool_choice")
    if isinstance(tool_choice, dict):
        tc = dict(tool_choice)
        ttype = tc.get("type")
        if ttype in ("function", "custom") and "name" in tc:
            tc["type"] = "function"
            tc["function"] = {"name": tc.pop("name")}
            # 清理残留的 custom 键
            tc.pop("custom", None)
        chat["tool_choice"] = tc
    elif tool_choice is not None:
        chat["tool_choice"] = tool_choice

    # reasoning.effort -> reasoning_effort（GPT 系列支持）
    reasoning = body_json.get("reasoning")
    if isinstance(reasoning, dict) and "effort" in reasoning:
        chat["reasoning_effort"] = reasoning["effort"]

    # text.format (JSON Schema 结构化输出) -> response_format
    text_cfg = body_json.get("text")
    if isinstance(text_cfg, dict) and text_cfg.get("format"):
        fmt = text_cfg["format"]
        if fmt == "json_object":
            chat["response_format"] = {"type": "json_object"}
        elif fmt == "text":
            chat["response_format"] = {"type": "text"}
        elif isinstance(fmt, dict) and fmt.get("type") == "json_schema":
            chat["response_format"] = {
                "type": "json_schema",
                "json_schema": {
                    "name": fmt.get("name", "default"),
                    "schema": fmt.get("schema", {}),
                    "strict": fmt.get("strict", False),
                }
            }
        else:
            chat["response_format"] = fmt

    # previous_response_id: Chat Completions API 不支持，直接丢弃。
    # 注意：Codex 若依赖 OpenAI 的 response 状态存储（而非全量上下文）做多轮对话会失效。
    # 已通过 disable_response_storage=true 强制 Codex 使用全量上下文模式，规避此限制。
    if "previous_response_id" in body_json:
        log("  [responses→chat] previous_response_id discarded (not supported by Chat Completions)")

    # seed / presence_penalty / frequency_penalty：Chat Completions 支持，直接透传
    for key in ("seed", "presence_penalty", "frequency_penalty"):
        if key in body_json:
            chat[key] = body_json[key]

    # 丢弃不支持的 Responses API 特有字段并记录日志
    for dropped_key in ("store", "truncation", "output", "modalities", "audio"):
        if dropped_key in body_json:
            log(f"  [responses→chat] {dropped_key} discarded (not supported by Chat Completions)")

    # 强制开启流式（codex 依赖 SSE 事件）
    if body_json.get("stream") is False:
        log("  [responses→chat] forcing stream=True (original stream=False discarded)")
    chat["stream"] = True

    # 第三方 OpenAI 兼容模型可能不支持 stream_options / parallel_tool_calls，避免报错
    model_name = body_json.get("model", "")
    is_compat_model = model_name in config.OPENAI_COMPAT_MODELS
    if not is_compat_model:
        if "stream_options" not in chat:
            chat["stream_options"] = {"include_usage": True}
    else:
        if "stream_options" in chat:
            del chat["stream_options"]
            log("  [responses→chat] stream_options stripped for compat model")
        if "parallel_tool_calls" in chat:
            del chat["parallel_tool_calls"]
            log("  [responses→chat] parallel_tool_calls stripped for compat model")

    return chat


class CodewizProvider(BaseProvider):
    def __init__(self, adapter_source: str | None = None):
        self._adapter_source = adapter_source

    def _effective_adapter_source(self) -> str:
        return self._adapter_source or config.ADAPTER_SOURCE

    def handle_anthropic(
        self,
        handler,
        body: bytes,
        provider_registry: "dict[str, BaseProvider] | None" = None,
    ) -> None:
        r = rewrite_body(body)
        for info in r.logs:
            log(f"  [rewrite] {info}")

        # 前缀路由：model name 指定了目标 provider，委托过去（传原始 body，让目标 provider 自己 rewrite，
        # 避免 billing header 等仅在首次 rewrite 中处理的字段在委托链中丢失）
        if r.provider_override and provider_registry:
            target = provider_registry.get(r.provider_override)
            if target is not None and target is not self:
                log(f"  [prefix route] → {r.provider_override}")
                target.handle_anthropic(handler, body, provider_registry=provider_registry)
                return
            if target is None:
                log(f"  [prefix route] 未知 provider '{r.provider_override}'，回退到当前 provider")

        # OpenAI 模型不能走 Anthropic 路径，直接拒绝
        if r.model_id in (config.OPENAI_NATIVE_MODELS | config.OPENAI_COMPAT_MODELS):
            log(f"  [error] OpenAI 模型 '{r.model_id}' 不能走 Anthropic 路径，请使用 Codex 客户端")
            handler.send_response(400)
            handler.send_header("Content-Type", "application/json")
            handler.end_headers()
            handler.wfile.write(json.dumps({
                "error": f"model '{r.model_id}' is an OpenAI model and cannot be used on the Anthropic path"
            }).encode())
            return

        if r.body_json:
            log(f"  model: {r.body_json.get('model', 'N/A')}  "
                f"stream: {r.body_json.get('stream', 'N/A')}  "
                f"messages: {len(r.body_json.get('messages', []))} 条")
            if config.VERBOSE:
                log(json.dumps(r.body_json, indent=2, ensure_ascii=False))
        else:
            log(f"  [body 解析失败, 长度: {len(r.body)} bytes]")

        target_url = config.TARGET_BASE_URL + handler.path
        req = urllib.request.Request(target_url, data=r.body, method="POST")

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

        for hk, hv in r.extra_headers.items():
            req.add_header(hk, hv)

        n, session_id, conversation_id = SESSION.bump_and_snapshot()
        should_report = bool(r.model_id and n % 3 == 0)

        forward(handler, req, r.body_json, r.model_id, n, session_id, conversation_id, should_report)

    def handle_openai(
        self,
        handler,
        body: bytes,
        provider_registry: "dict[str, BaseProvider] | None" = None,
    ) -> None:
        # 复用 rewrite_body 做前缀路由解析和 billing header 提取（OpenAI 路径不剥 metadata/service_tier）
        r = rewrite_body(body, is_openai=True)
        for info in r.logs:
            log(f"  [rewrite] {info}")

        # 前缀路由：委托给其他 provider 的 openai 路径（传原始 body，避免委托链中字段丢失）
        if r.provider_override and provider_registry:
            target = provider_registry.get(r.provider_override)
            if target is not None and target is not self:
                log(f"  [prefix route/openai] → {r.provider_override}")
                target.handle_openai(handler, body, provider_registry=provider_registry)
                return
            if target is None:
                log(f"  [prefix route/openai] 未知 provider '{r.provider_override}'，回退到当前 provider")

        body_json = r.body_json
        body = r.body
        model = body_json.get("model", "N/A")

        # /responses 路径（Codex 使用的 OpenAI Responses API）需要转成 /v1/chat/completions
        is_responses_path = handler.path in ("/responses", "/v1/responses")
        if is_responses_path:
            chat_body_json = _convert_responses_to_chat(body_json)
            chat_body = json.dumps(chat_body_json).encode("utf-8")
            target_path = "/v1/chat/completions"
            log(f"  [responses→chat] model: {model}  path: {handler.path} → {target_path}")
            if config.VERBOSE:
                log(json.dumps(chat_body_json, indent=2, ensure_ascii=False))
        else:
            chat_body_json = body_json
            chat_body = body
            target_path = handler.path
            is_native = model in config.OPENAI_NATIVE_MODELS
            is_compat = model in config.OPENAI_COMPAT_MODELS
            provider_tag = "openai-native" if is_native else ("openai-compat" if is_compat else "openai-unknown")
            log(f"  [openai/{provider_tag}] model: {model}  path: {handler.path}")
            if config.VERBOSE:
                log(json.dumps(body_json, indent=2, ensure_ascii=False))

        target_url = config.OPENAI_TARGET_BASE_URL + target_path
        req = urllib.request.Request(target_url, data=chat_body, method="POST")

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

        for hk, hv in r.extra_headers.items():
            req.add_header(hk, hv)

        # 第三方兼容模型需附加固定 api-key header（openai-native GPT 系列不需要）
        if not is_responses_path:
            is_compat = model in config.OPENAI_COMPAT_MODELS
            if is_compat:
                req.add_header(config.OPENAI_COMPAT_API_KEY_HEADER, config.OPENAI_COMPAT_API_KEY_VALUE)
        else:
            # /responses 路径：按转换后的 model 判断是否需附加 api-key header
            if model in config.OPENAI_COMPAT_MODELS:
                req.add_header(config.OPENAI_COMPAT_API_KEY_HEADER, config.OPENAI_COMPAT_API_KEY_VALUE)

        if is_responses_path:
            forward_responses(handler, req, model)
        else:
            n, session_id, conversation_id = SESSION.bump_and_snapshot()
            forward(handler, req, chat_body_json, model, n, session_id, conversation_id, False)
