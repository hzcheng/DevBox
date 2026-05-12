from __future__ import annotations

import json
import random
import threading
import time
import urllib.request
import uuid

from . import config, credentials
from .utils import log


def _now_ms() -> int:
    return int(time.time() * 1000)


def _call_id() -> str:
    return f"call_{random.getrandbits(64):016x}"


def _http_post_fire_and_forget(url: str, payload_bytes: bytes) -> None:
    try:
        req = urllib.request.Request(url, data=payload_bytes, method="POST")
        req.add_header("Content-Type", "application/json")
        urllib.request.urlopen(req, context=config._SSL_CTX, timeout=10)
    except Exception:
        pass


def _track(event: str, values: dict) -> None:
    merged = {"codewiz_opencode_version": config.CODEWIZ_VERSION, "bizSource": "openCode"}
    merged.update(values)
    payload = {
        "timestamp": _now_ms(),
        "metricsScene": "cli",
        "metricsKey": f"codewiz_opencode_{event}",
        "sessionId": merged.get("sessionID", ""),
        "llmModel": merged.get("modelID", ""),
        "mainAgent": merged.get("agent", ""),
        "conversationId": merged.get("conversationId", ""),
        "userInfo": json.dumps(credentials.USER_INFO),
        "metricsValue": json.dumps(merged),
    }
    _http_post_fire_and_forget(config.METRICS_API, json.dumps(payload).encode())


def _cat_report(metrics: dict) -> None:
    env = {"ideSeries": "cli", "idePlatform": "codewiz-opencode",
           "module": "cli", "adapterVersion": config.CODEWIZ_VERSION}
    env.update(metrics)
    _http_post_fire_and_forget(config.METRICS_EXTENDED_API, json.dumps({"metrics": [env]}).encode())


def _report_log(msg: str, session_id: str) -> None:
    entry = {
        "level": "info", "msg": msg, "ide": "codewiz-opencode",
        "module": "codewiz-opencode", "clientTimestamp": str(_now_ms()),
        "traceId": "", "sessionId": session_id, "requestId": "",
        "pluginName": "cli", "env": {"userId": credentials.USER_EMAIL, "pluginVersion": config.CODEWIZ_VERSION},
    }
    _http_post_fire_and_forget(config.LOG_API, json.dumps([entry]).encode())


class SessionState:
    def __init__(self):
        self.session_id = str(uuid.uuid4())
        self.conversation_id = str(uuid.uuid4())
        self.request_count = 0
        self._lock = threading.Lock()

    def bump_and_snapshot(self) -> tuple[int, str, str]:
        with self._lock:
            n = self.request_count
            self.request_count += 1
            if n > 0 and n % 10 == 0:
                self.conversation_id = str(uuid.uuid4())
            return n, self.session_id, self.conversation_id


SESSION = SessionState()


def fire_fake_session(model_id: str, session_id: str, conversation_id: str,
                      input_tokens: int, output_tokens: int,
                      cache_read: int, cache_write: int) -> None:
    """模拟一个完整的 codewiz CLI 会话上报"""
    message_id = str(uuid.uuid4())
    agent = "coder"
    base = {"sessionID": session_id, "conversationId": conversation_id,
            "agent": agent, "modelID": model_id}

    _track("user_input", {**base, "messageID": message_id, "query": "help me with this code"})
    _track("task_conversation_message", {**base, "source": "user"})
    time.sleep(0.05)
    _track("llm_completion", {**base, "inputTokens": input_tokens, "outputTokens": output_tokens,
                               "cacheReadTokens": cache_read, "cacheWriteTokens": cache_write})

    cid = _call_id()
    tool_name = "Read"
    _track("tool_execute", {**base, "callID": cid, "tool": tool_name})
    _cat_report({"name": "codewiz_opencode_tool_execute", "type": "counter",
                 "tags": {"tool": tool_name, "sessionID": session_id,
                          "conversationId": conversation_id}, "value": 1})
    tool_duration = 30 + random.randint(0, 200)
    time.sleep(0.02)
    _track("tool_execute_success", {**base, "callID": cid, "tool": tool_name})
    _track("tool_execute_duration", {**base, "callID": cid, "tool": tool_name,
                                     "duration": tool_duration, "success": True})
    _cat_report({"name": "codewiz_opencode_tool_execute_duration", "type": "summary",
                 "tags": {"tool": tool_name, "sessionID": session_id,
                          "conversationId": conversation_id}, "value": tool_duration})
    _track("task_conversation_message", {**base, "source": "assistant"})
    _report_log(f"llm call completed model={model_id}", session_id)
