from __future__ import annotations


def convert_responses_to_chat(body: dict, default_model: str = "") -> dict:
    """把 Codex 发的 /responses 格式转成 /v1/chat/completions 格式"""
    messages = []

    instructions = body.get("instructions")
    if instructions:
        messages.append({"role": "system", "content": instructions})

    pending_tool_calls = []
    for item in body.get("input", []):
        typ = item.get("type", "")

        if typ == "function_call":
            pending_tool_calls.append({
                "id": item.get("call_id", ""),
                "type": "function",
                "function": {
                    "name": item.get("name", ""),
                    "arguments": item.get("arguments", ""),
                },
            })
            continue

        if typ == "function_call_output":
            if pending_tool_calls:
                messages.append({"role": "assistant", "content": "", "tool_calls": pending_tool_calls})
                pending_tool_calls = []
            messages.append({
                "role": "tool",
                "tool_call_id": item.get("call_id", ""),
                "content": str(item.get("output", "")),
            })
            continue

        if pending_tool_calls:
            messages.append({"role": "assistant", "content": "", "tool_calls": pending_tool_calls})
            pending_tool_calls = []

        if typ != "message":
            continue

        role = item.get("role", "user")
        if role == "developer":
            role = "user"
        content_parts = item.get("content", [])
        texts = []
        for part in content_parts:
            if isinstance(part, dict) and part.get("type") in ("input_text", "text", "output_text"):
                texts.append(part.get("text", ""))
            elif isinstance(part, str):
                texts.append(part)
        content = "\n".join(texts) if texts else ""
        if role == "assistant" and not content:
            continue
        messages.append({"role": role, "content": content})

    if pending_tool_calls:
        messages.append({"role": "assistant", "content": "", "tool_calls": pending_tool_calls})

    result = {
        "model": body.get("model", default_model),
        "messages": messages,
        "stream": body.get("stream", True),
    }

    if "tools" in body:
        valid_tools = [
            t for t in body["tools"]
            if t.get("type") == "function" and t.get("function", {}).get("name")
        ]
        if valid_tools:
            result["tools"] = valid_tools

    if "max_output_tokens" in body:
        result["max_tokens"] = body["max_output_tokens"]

    return result
