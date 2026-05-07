"""
proxy.py — CodeWiz LLM Proxy for Claude Code & Codex

凭据优先级:
  1. 环境变量 CODEWIZ_SESSION_TOKEN / CODEWIZ_USER_EMAIL
  2. 自动检测 ~/.local/share/codewiz/auth.json

可选环境变量:
  CODEWIZ_TARGET_URL        - Claude 后端（默认: https://codewiz.devops.xiaohongshu.com/llmadapter/v3/claude）
  CODEWIZ_OPENAI_TARGET_URL - OpenAI 后端（默认: https://codewiz.devops.xiaohongshu.com/llmratelimit/v3/openai/v1）
  CODEWIZ_PROXY_PORT        - 监听端口（默认: 8089）
  CODEWIZ_INITIAL_PROVIDER  - 启动时使用的 provider（codewiz | kimi，默认: codewiz）

运行时切换 provider（无需重启）:
  claude-use kimi
  claude-use codewiz
  claude-use status
"""

import argparse
import base64
import http.server
import json
import os
import random
import socketserver
import ssl
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime

# ── 配置 ──
TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_TARGET_URL",
    "https://codewiz.devops.xiaohongshu.com/llmadapter/v3/claude",
)
OPENAI_TARGET_BASE_URL = os.environ.get(
    "CODEWIZ_OPENAI_TARGET_URL",
    "https://codewiz.devops.xiaohongshu.com/llmratelimit/v3/openai/v1",
)
PORT = int(os.environ.get("CODEWIZ_PROXY_PORT", "8089"))

KIMI_TARGET_BASE_URL = "https://api.kimi.com/coding"
KIMI_MODEL = "kimi-for-coding"
KIMI_USER_AGENT = "KimiCLI/1.37.0"
KIMI_CREDENTIALS_PATH = os.path.join(os.environ.get("HOME", "/root"), ".kimi", "credentials", "kimi-code.json")
KIMI_OAUTH_TOKEN_URL = "https://auth.kimi.com/api/oauth/token"

CODEWIZ_VERSION = "0.1.37"

METRICS_API = "http://codewiz.devops.xiaohongshu.com/complete/metrics/v1"
METRICS_EXTENDED_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/metrics-extended/batch"
LOG_API = "http://codewiz.devops.xiaohongshu.com/complete/api/v1/logs/batch"

MODEL_MAP = {
    "claude-sonnet-4-6":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-6-20250627":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250514":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-5-20250929":  "claude-4.6-sonnet-google",
    "claude-sonnet-4-20250514":    "claude-4.6-sonnet-google",
    "claude-opus-4-6":             "claude-4.6-opus-google",
    "claude-opus-4-6-20250627":    "claude-4.6-opus-google",
    "claude-opus-4-0-20250515":    "claude-4.6-opus-google",
    "claude-haiku-4-5":            "claude-4.5-haiku-google",
    "claude-haiku-4-5-20251001":   "claude-4.5-haiku-google",
    "claude-sonnet-4-0":           "claude-4.6-sonnet-google",
    "claude-sonnet-4-0-20250514":  "claude-4.6-sonnet-google",
}

# ── 需要剥离的请求体字段 ──
STRIP_FIELDS = {
    "thinking", "output_config", "temperature_presets",
    "service_tier", "context_management", "betas", "metadata",
}

# ── Beta header 白名单前缀 ──
ALLOWED_BETA_PREFIXES = (
    "prompt-caching-2", "max-tokens-", "output-", "token-counting-",
    "interleaved-thinking-", "extended-cache-ttl-",
)

# ── 全局状态 ──
VERBOSE = False
LOG_FILE = None
ADAPTER_SOURCE = "codewiz-cli"
_SSL_CTX = ssl.create_default_context()

# ── Provider 状态（运行时可切换） ──
_PROVIDER_LOCK = threading.Lock()
_CURRENT_PROVIDER = os.environ.get("CODEWIZ_INITIAL_PROVIDER", "codewiz")

def get_provider():
    with _PROVIDER_LOCK:
        return _CURRENT_PROVIDER

def set_provider(name):
    global _CURRENT_PROVIDER
    with _PROVIDER_LOCK:
        _CURRENT_PROVIDER = name

# ── 凭据（启动时填充） ──
SESSION_TOKEN = ""
SSO_TOKEN_KEY = "common-internal-access-token-prod"
USER_EMAIL = ""
USER_INFO = {}

# ── Kimi Token（运行时刷新） ──
_KIMI_LOCK = threading.Lock()
_KIMI_ACCESS_TOKEN = ""
_KIMI_REFRESH_TOKEN = ""
_KIMI_EXPIRES_AT = 0.0


# ── 工具函数 ──
def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    if LOG_FILE:
        LOG_FILE.write(line + "\n")
        LOG_FILE.flush()


def filter_beta_header(value):
    betas = [b.strip() for b in value.split(",") if b.strip()]
    filtered = [b for b in betas if any(b.startswith(p) for p in ALLOWED_BETA_PREFIXES)]
    return ", ".join(filtered) if filtered else None


def extract_billing_header(body_json):
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


def _strip_cache_control_scope(obj):
    """递归删除所有 cache_control 对象中的 scope 字段"""
    if isinstance(obj, dict):
        if "cache_control" in obj and isinstance(obj["cache_control"], dict):
            obj["cache_control"].pop("scope", None)
        for v in obj.values():
            _strip_cache_control_scope(v)
    elif isinstance(obj, list):
        for item in obj:
            _strip_cache_control_scope(item)


def rewrite_body(body_bytes):
    """模型映射 + 剥离不支持的字段，返回 (new_body, body_json, extra_headers, logs, model_id)"""
    try:
        body_json = json.loads(body_bytes)
    except (json.JSONDecodeError, ValueError):
        return body_bytes, {}, {}, [], None

    logs = []
    extra_headers = {}
    model_id = None

    original_model = body_json.get("model", "")
    if original_model in MODEL_MAP:
        mapped = MODEL_MAP[original_model]
        logs.append(f"model: {original_model} -> {mapped}")
        model_id = mapped
        body_json["model"] = mapped
    elif original_model:
        model_id = original_model

    for key in STRIP_FIELDS:
        if key in body_json:
            del body_json[key]
            logs.append(f"stripped: {key}")

    billing_val, billing_logs = extract_billing_header(body_json)
    logs.extend(billing_logs)
    if billing_val:
        extra_headers["x-anthropic-billing-header"] = billing_val

    _strip_cache_control_scope(body_json)

    return json.dumps(body_json).encode("utf-8"), body_json, extra_headers, logs, model_id


def extract_usage(data):
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


# ── Kimi 凭据 ──
def _load_kimi_credentials_from_file():
    """从 kimi-cli 的凭据文件读取 token，返回 (access_token, refresh_token, expires_at) 或 None"""
    try:
        with open(KIMI_CREDENTIALS_PATH) as f:
            data = json.load(f)
        return data["access_token"], data["refresh_token"], float(data["expires_at"])
    except (OSError, KeyError, ValueError):
        return None


def _refresh_kimi_token(refresh_token):
    """用 refresh_token 换新的 access_token，成功返回 (access_token, refresh_token, expires_at)，失败返回 None"""
    payload = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": "17e5f671-d194-4dfb-9706-5516cb48c098",
    }).encode()
    try:
        req = urllib.request.Request(KIMI_OAUTH_TOKEN_URL, data=payload, method="POST")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
        req.add_header("User-Agent", KIMI_USER_AGENT)
        resp = urllib.request.urlopen(req, context=_SSL_CTX, timeout=15)
        data = json.loads(resp.read())
        expires_at = time.time() + float(data["expires_in"])
        return data["access_token"], data.get("refresh_token", refresh_token), expires_at
    except Exception as e:
        log(f"[kimi] token 刷新失败: {e}")
        return None


def get_kimi_token():
    """获取有效的 Kimi access_token，必要时自动刷新"""
    global _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT
    with _KIMI_LOCK:
        # token 还有 60 秒以上有效期则直接返回
        if _KIMI_ACCESS_TOKEN and time.time() < _KIMI_EXPIRES_AT - 60:
            return _KIMI_ACCESS_TOKEN

        # 尝试从文件重新加载（kimi-cli 可能已刷新过）
        creds = _load_kimi_credentials_from_file()
        if creds:
            access, refresh, expires_at = creds
            if time.time() < expires_at - 60:
                _KIMI_ACCESS_TOKEN = access
                _KIMI_REFRESH_TOKEN = refresh
                _KIMI_EXPIRES_AT = expires_at
                log("[kimi] 从凭据文件加载 token")
                return _KIMI_ACCESS_TOKEN
            # 文件里的 token 也快过期了，用 refresh_token 刷新
            _KIMI_REFRESH_TOKEN = refresh

        if not _KIMI_REFRESH_TOKEN:
            raise RuntimeError("Kimi 未登录，请先运行 kimi-cli 完成登录")

        result = _refresh_kimi_token(_KIMI_REFRESH_TOKEN)
        if not result:
            raise RuntimeError("Kimi token 刷新失败")

        _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT = result
        # 写回文件，保持与 kimi-cli 同步
        try:
            with open(KIMI_CREDENTIALS_PATH, "w") as f:
                json.dump({
                    "access_token": _KIMI_ACCESS_TOKEN,
                    "refresh_token": _KIMI_REFRESH_TOKEN,
                    "expires_at": _KIMI_EXPIRES_AT,
                    "scope": "kimi-code",
                    "token_type": "Bearer",
                    "expires_in": _KIMI_EXPIRES_AT - time.time(),
                }, f)
            log("[kimi] token 已刷新并写回凭据文件")
        except OSError:
            pass

        return _KIMI_ACCESS_TOKEN


def load_kimi_credentials():
    """启动时预加载 Kimi token（provider=kimi 时调用）"""
    global _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT
    creds = _load_kimi_credentials_from_file()
    if not creds:
        print("=" * 60)
        print("错误: 找不到 Kimi 凭据文件")
        print(f"  路径: {KIMI_CREDENTIALS_PATH}")
        print("请先通过 kimi-cli 或 Kimi Code VS Code 插件登录")
        print("=" * 60)
        sys.exit(1)
    _KIMI_ACCESS_TOKEN, _KIMI_REFRESH_TOKEN, _KIMI_EXPIRES_AT = creds
    log(f"[kimi] 已加载 token，有效期至 {datetime.fromtimestamp(_KIMI_EXPIRES_AT).strftime('%H:%M:%S')}")


# ── 凭据加载 ──
def _read_token_from_auth_json():
    path = os.path.join(os.environ.get("HOME", "/root"),
                        ".local", "share", "codewiz", "auth.json")
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    for val in data.values():
        if isinstance(val, dict) and val.get("type") == "wellknown":
            token = val.get("token")
            if isinstance(token, str):
                return token
    return None


def _auto_detect_credentials():
    token_b64 = _read_token_from_auth_json()
    if not token_b64:
        return None
    try:
        v = json.loads(base64.b64decode(token_b64))
    except Exception:
        return None
    sso_token = v.get("ssoAccessToken")
    if not sso_token:
        return None
    return {
        "sso_token": sso_token,
        "sso_token_key": v.get("ssoAccessTokenKey", "common-internal-access-token-prod"),
        "email": v.get("email", ""),
        "user_info": {
            "name": v.get("name", ""),
            "email": v.get("email", ""),
            "userId": v.get("userId", ""),
            "accountNo": v.get("accountNo", ""),
            "userNameAlias": v.get("userNameAlias", ""),
        },
    }


def load_credentials():
    global SESSION_TOKEN, SSO_TOKEN_KEY, USER_EMAIL, USER_INFO

    env_token = os.environ.get("CODEWIZ_SESSION_TOKEN", "")
    env_email = os.environ.get("CODEWIZ_USER_EMAIL", "")
    creds = _auto_detect_credentials()

    if env_token:
        SESSION_TOKEN = env_token
    elif creds:
        SESSION_TOKEN = creds["sso_token"]
        SSO_TOKEN_KEY = creds["sso_token_key"]
        log("自动检测 SSO token (from auth.json)")
    else:
        SESSION_TOKEN = ""

    if env_email:
        USER_EMAIL = env_email
    elif creds:
        USER_EMAIL = creds["email"]
        log(f"自动检测 email: {USER_EMAIL}")
    else:
        USER_EMAIL = ""

    USER_INFO = creds["user_info"] if creds else {}

    if not SESSION_TOKEN or not USER_EMAIL:
        missing = []
        if not SESSION_TOKEN:
            missing.append("SSO Token")
        if not USER_EMAIL:
            missing.append("Email")
        print("=" * 60)
        print(f"错误: 缺少凭据: {', '.join(missing)}")
        print()
        print("方式一: 运行 `codewiz auth login` 生成 auth.json（推荐）")
        print()
        print("方式二: 手动设置环境变量:")
        print('  export CODEWIZ_SESSION_TOKEN="AT-xxx"')
        print('  export CODEWIZ_USER_EMAIL="yourname@xiaohongshu.com"')
        print("=" * 60)
        sys.exit(1)


# ── 遥测 ──
def _now_ms():
    return int(time.time() * 1000)


def _call_id():
    return f"call_{random.getrandbits(64):016x}"


def _http_post_fire_and_forget(url, payload_bytes):
    try:
        req = urllib.request.Request(url, data=payload_bytes, method="POST")
        req.add_header("Content-Type", "application/json")
        urllib.request.urlopen(req, context=_SSL_CTX, timeout=10)
    except Exception:
        pass


def _track(event, values):
    merged = {"codewiz_opencode_version": CODEWIZ_VERSION, "bizSource": "openCode"}
    merged.update(values)
    payload = {
        "timestamp": _now_ms(),
        "metricsScene": "cli",
        "metricsKey": f"codewiz_opencode_{event}",
        "sessionId": merged.get("sessionID", ""),
        "llmModel": merged.get("modelID", ""),
        "mainAgent": merged.get("agent", ""),
        "conversationId": merged.get("conversationId", ""),
        "userInfo": json.dumps(USER_INFO),
        "metricsValue": json.dumps(merged),
    }
    _http_post_fire_and_forget(METRICS_API, json.dumps(payload).encode())


def _cat_report(metrics):
    env = {"ideSeries": "cli", "idePlatform": "codewiz-opencode",
           "module": "cli", "adapterVersion": CODEWIZ_VERSION}
    env.update(metrics)
    _http_post_fire_and_forget(METRICS_EXTENDED_API, json.dumps({"metrics": [env]}).encode())


def _report_log(msg, session_id):
    entry = {
        "level": "info", "msg": msg, "ide": "codewiz-opencode",
        "module": "codewiz-opencode", "clientTimestamp": str(_now_ms()),
        "traceId": "", "sessionId": session_id, "requestId": "",
        "pluginName": "cli", "env": {"userId": USER_EMAIL, "pluginVersion": CODEWIZ_VERSION},
    }
    _http_post_fire_and_forget(LOG_API, json.dumps([entry]).encode())


# ── 会话状态（用于遥测） ──
class SessionState:
    def __init__(self):
        self.session_id = str(uuid.uuid4())
        self.conversation_id = str(uuid.uuid4())
        self.request_count = 0
        self._lock = threading.Lock()

    def bump(self):
        with self._lock:
            n = self.request_count
            self.request_count += 1
            if n > 0 and n % 10 == 0:
                self.conversation_id = str(uuid.uuid4())
            return n

    def snapshot(self):
        with self._lock:
            return self.session_id, self.conversation_id


SESSION = SessionState()


def fire_fake_session(model_id, session_id, conversation_id,
                      input_tokens, output_tokens, cache_read, cache_write):
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


# ── OpenAI Responses API → Chat Completions 格式转换 ──
def _convert_responses_to_chat(body: dict) -> dict:
    """把 Codex 发的 /responses 格式转成 /v1/chat/completions 格式"""
    messages = []

    # instructions → system message
    instructions = body.get("instructions")
    if instructions:
        messages.append({"role": "system", "content": instructions})

    # input → messages
    # 合并连续的 function_call + function_call_output 成 assistant+tool 对
    pending_tool_calls = []  # 积累 assistant 的 function_call 条目
    for item in body.get("input", []):
        typ = item.get("type", "")

        if typ == "function_call":
            # assistant 发起的 tool call
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
            # tool 执行结果 — 先把积累的 tool_calls flush 成 assistant 消息
            if pending_tool_calls:
                messages.append({"role": "assistant", "content": "", "tool_calls": pending_tool_calls})
                pending_tool_calls = []
            messages.append({
                "role": "tool",
                "tool_call_id": item.get("call_id", ""),
                "content": str(item.get("output", "")),
            })
            continue

        # 遇到非 tool 类型时先 flush 积累的 tool_calls
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
        # 过滤掉空内容的 assistant 消息
        if role == "assistant" and not content:
            continue
        messages.append({"role": role, "content": content})

    # flush 末尾残留的 tool_calls
    if pending_tool_calls:
        messages.append({"role": "assistant", "content": "", "tool_calls": pending_tool_calls})

    result = {
        "model": body.get("model", KIMI_MODEL),
        "messages": messages,
        "stream": body.get("stream", True),
    }

    # 只透传 function 类型的 tools，过滤掉 web_search 等 kimi 不支持的类型
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


# ── 请求处理 ──
class ProxyHandler(http.server.BaseHTTPRequestHandler):

    def _is_openai_path(self):
        # codex wire_api=responses 发 /responses
        # codex wire_api=chat 发 /v1/chat/completions
        return self.path.startswith("/responses") or self.path.startswith("/v1/chat")

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        log("=" * 50)
        log(f"{self.command} {self.path}")

        provider = get_provider()

        if self._is_openai_path():
            if provider == "kimi":
                self._do_kimi_openai_post(body)
            else:
                self._do_openai_post(body)
            return

        if provider == "kimi":
            self._do_kimi_post(body)
            return

        body, body_json, extra_headers, rewrite_logs, model_id = rewrite_body(body)
        for info in rewrite_logs:
            log(f"  [rewrite] {info}")

        if body_json:
            log(f"  model: {body_json.get('model', 'N/A')}  "
                f"stream: {body_json.get('stream', 'N/A')}  "
                f"messages: {len(body_json.get('messages', []))} 条")
            if VERBOSE:
                log(json.dumps(body_json, indent=2, ensure_ascii=False))
        else:
            log(f"  [body 解析失败, 长度: {len(body)} bytes]")

        target_url = TARGET_BASE_URL + self.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection"}
        for key, value in self.headers.items():
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

        req.add_header("Cookie", f"{SSO_TOKEN_KEY}={SESSION_TOKEN}")
        req.add_header(SSO_TOKEN_KEY, SESSION_TOKEN)
        req.add_header("x-adapter-source", ADAPTER_SOURCE)
        req.add_header("x-adapter-email", USER_EMAIL)
        req.add_header("X-Adapter-User-Email", USER_EMAIL)
        req.add_header("x-adapter-scenario", "codewiz-opencode-cli")

        for hk, hv in extra_headers.items():
            req.add_header(hk, hv)

        n = SESSION.bump()
        session_id, conversation_id = SESSION.snapshot()
        should_report = bool(model_id and n % 3 == 0)

        self._forward(req, body_json, model_id, n, session_id, conversation_id, should_report)

    def _do_kimi_post(self, body):
        """转发 Anthropic 格式请求到 Kimi Coding API"""
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        # 剥离不兼容字段，提取 billing header（kimi 不需要）
        body, body_json, _extra, rewrite_logs, _ = rewrite_body(body)
        for info in rewrite_logs:
            log(f"  [kimi/rewrite] {info}")

        # 所有 claude 模型都映射到 kimi-for-coding
        original_model = body_json.get("model", "")
        if original_model != KIMI_MODEL:
            body_json["model"] = KIMI_MODEL
            log(f"  [kimi] model: {original_model} -> {KIMI_MODEL}")
            body = json.dumps(body_json).encode("utf-8")

        log(f"  [kimi] stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")
        if VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        try:
            token = get_kimi_token()
        except RuntimeError as e:
            log(f"  [kimi] 获取 token 失败: {e}")
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
            return

        target_url = KIMI_TARGET_BASE_URL + self.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "anthropic-version", "x-api-key"}
        for key, value in self.headers.items():
            if key.lower() in skip_headers:
                continue
            if key.lower() == "anthropic-beta":
                filtered = filter_beta_header(value)
                if filtered:
                    req.add_header(key, filtered)
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("User-Agent", KIMI_USER_AGENT)

        n = SESSION.bump()
        self._forward(req, body_json, KIMI_MODEL, n, *SESSION.snapshot(), False)

    def _do_kimi_openai_post(self, body):
        """转发 OpenAI 格式请求（Codex CLI 使用）到 Kimi Coding API。
        /responses 格式会被转换成 /v1/chat/completions 格式。
        """
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        # /responses 格式 → /v1/chat/completions 格式转换
        is_responses = self.path.startswith("/responses")
        if is_responses:
            body_json = _convert_responses_to_chat(body_json)
            target_path = "/v1/chat/completions"
        else:
            target_path = self.path

        original_model = body_json.get("model", "")
        if original_model != KIMI_MODEL:
            body_json["model"] = KIMI_MODEL
            log(f"  [kimi/openai] model: {original_model} -> {KIMI_MODEL}")

        body = json.dumps(body_json).encode("utf-8")
        log(f"  [kimi/openai] path: {target_path}  stream: {body_json.get('stream', 'N/A')}  "
            f"messages: {len(body_json.get('messages', []))} 条")
        if VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        try:
            token = get_kimi_token()
        except RuntimeError as e:
            log(f"  [kimi/openai] 获取 token 失败: {e}")
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
            return

        target_url = KIMI_TARGET_BASE_URL + target_path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-anthropic-billing-header"}
        for key, value in self.headers.items():
            if key.lower() in skip_headers:
                continue
            req.add_header(key, value)

        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("User-Agent", KIMI_USER_AGENT)

        n = SESSION.bump()
        if is_responses:
            self._forward_responses(req)
        else:
            self._forward(req, body_json, KIMI_MODEL, n, *SESSION.snapshot(), False)

    def _forward_responses(self, req):
        """把 kimi chat.completion.chunk SSE 流转成 OpenAI Responses API SSE 流"""
        start_time = time.time()
        try:
            resp = urllib.request.urlopen(req, context=_SSL_CTX, timeout=600)
            elapsed = time.time() - start_time
            log(f"响应 {resp.status} ({elapsed:.1f}s) [responses转换]")
        except urllib.error.HTTPError as e:
            elapsed = time.time() - start_time
            error_body = e.read()
            log(f"错误 {e.code} ({elapsed:.1f}s): {repr(error_body[:300])}")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(error_body)
            return
        except Exception as e:
            elapsed = time.time() - start_time
            log(f"异常 ({elapsed:.1f}s): {e}")
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
            return

        resp_id = f"resp_{uuid.uuid4().hex}"
        created_at = int(time.time())
        seq = 0

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        def sse(event, data):
            data["sequence_number"] = seq
            return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n".encode()

        def send(event, data):
            nonlocal seq
            self.wfile.write(sse(event, data))
            self.wfile.flush()
            seq += 1

        base_resp = {
            "id": resp_id, "object": "response", "created_at": created_at,
            "status": "in_progress", "model": KIMI_MODEL, "output": [], "usage": None,
        }
        send("response.created", {"type": "response.created", "response": dict(base_resp)})
        send("response.in_progress", {"type": "response.in_progress", "response": dict(base_resp)})

        # 解析 kimi SSE 流，先收集所有 chunks 再决定是文本还是 tool call
        full_text = []
        tool_calls_buf = {}  # index -> {id, name, args, item_id}
        msg_item_id = f"msg_{uuid.uuid4().hex}"
        text_item_started = False

        buf = b""
        try:
            for chunk in resp:
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if not line.startswith(b"data:"):
                        continue
                    payload = line[5:].strip()
                    if payload == b"[DONE]":
                        break
                    try:
                        cj = json.loads(payload)
                    except (json.JSONDecodeError, ValueError):
                        continue
                    choices = cj.get("choices", [])
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})

                    text = delta.get("content") or ""
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

                    for tc in delta.get("tool_calls", []):
                        idx = tc.get("index", 0)
                        if idx not in tool_calls_buf:
                            tc_item_id = f"fc_{uuid.uuid4().hex}"
                            call_id = tc.get("id", f"call_{uuid.uuid4().hex[:8]}")
                            tool_calls_buf[idx] = {
                                "id": call_id, "item_id": tc_item_id, "name": "", "args": "",
                            }
                            send("response.output_item.added", {
                                "type": "response.output_item.added", "output_index": idx,
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
                                "output_index": idx, "item_id": entry["item_id"],
                                "delta": args_delta,
                            })
        except Exception as e:
            log(f"  [responses转换] 流读取异常: {e}")

        # 收尾：文本部分
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

        # 收尾：tool calls
        for idx in sorted(tool_calls_buf):
            entry = tool_calls_buf[idx]
            send("response.function_call_arguments.done", {
                "type": "response.function_call_arguments.done",
                "output_index": idx, "item_id": entry["item_id"],
                "arguments": entry["args"],
            })
            fc_item = {"id": entry["item_id"], "type": "function_call", "status": "completed",
                       "call_id": entry["id"], "name": entry["name"], "arguments": entry["args"]}
            send("response.output_item.done", {
                "type": "response.output_item.done", "output_index": idx, "item": fc_item,
            })
            output_items.append(fc_item)

        send("response.completed", {
            "type": "response.completed",
            "response": {**base_resp, "status": "completed", "output": output_items},
        })

    def _do_openai_post(self, body):
        """转发 OpenAI 格式请求（Codex CLI 使用）到内部 OpenAI endpoint"""
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        # 剥离 billing header（CodeWiz 后端无法解密 Anthropic 的加密票据）
        if isinstance(body_json.get("system"), list):
            _, _ = extract_billing_header(body_json)
            body = json.dumps(body_json).encode("utf-8")

        model = body_json.get("model", "N/A")
        log(f"  [openai] model: {model}  path: {self.path}")
        if VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        target_url = OPENAI_TARGET_BASE_URL + self.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization", "x-anthropic-billing-header"}
        for key, value in self.headers.items():
            if key.lower() in skip_headers:
                continue
            req.add_header(key, value)

        req.add_header("Cookie", f"{SSO_TOKEN_KEY}={SESSION_TOKEN}")
        req.add_header(SSO_TOKEN_KEY, SESSION_TOKEN)
        req.add_header("x-adapter-source", ADAPTER_SOURCE)
        req.add_header("x-adapter-email", USER_EMAIL)
        req.add_header("X-Adapter-User-Email", USER_EMAIL)
        req.add_header("x-adapter-scenario", "codewiz-opencode-cli")

        n = SESSION.bump()
        self._forward(req, body_json, model, n, *SESSION.snapshot(), False)

    def _forward(self, req, body_json, model_id, n, session_id, conversation_id, should_report):
        ctx = _SSL_CTX
        start_time = time.time()
        try:
            resp = urllib.request.urlopen(req, context=ctx, timeout=600)
            elapsed = time.time() - start_time
            log(f"响应 {resp.status} ({elapsed:.1f}s)")

            self.send_response(resp.status)
            for key, value in resp.getheaders():
                if key.lower() not in ("transfer-encoding", "connection"):
                    self.send_header(key, value)
            self.end_headers()

            collected = bytearray()
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
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
                f"~/.cache/claude_proxy/codewiz_failed_{int(time.time())}.json"
            )
            os.makedirs(os.path.dirname(dump_path), exist_ok=True)
            try:
                with open(dump_path, "w", encoding="utf-8") as f:
                    json.dump(body_json, f, ensure_ascii=False, indent=2)
                log(f"  body dumped to: {dump_path}")
            except Exception as dump_err:
                log(f"  dump failed: {dump_err}")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(error_body)

        except Exception as e:
            elapsed = time.time() - start_time
            log(f"异常 ({elapsed:.1f}s): {e}")
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_GET(self):
        if self.path in ("/api/hello", "/v1/oauth/hello"):
            self._json_response({"status": "ok"})
            return

        if self.path == "/admin/status":
            provider = get_provider()
            info = {"provider": provider, "port": PORT}
            if provider == "kimi":
                with _KIMI_LOCK:
                    remaining = max(0, int(_KIMI_EXPIRES_AT - time.time()))
                info["kimi_token_ttl_seconds"] = remaining
            else:
                info["codewiz_user"] = USER_EMAIL
            self._json_response(info)
            return

        if self.path.startswith("/admin/switch"):
            from urllib.parse import urlparse, parse_qs
            qs = parse_qs(urlparse(self.path).query)
            name = (qs.get("provider") or [""])[0].strip()
            allowed = {"codewiz", "openclaw", "kimi"}
            if name not in allowed:
                self._json_response(
                    {"error": f"unknown provider '{name}', allowed: {sorted(allowed)}"},
                    status=400,
                )
                return
            set_provider(name)
            log(f"[admin] provider 切换为: {name}")
            self._json_response({"ok": True, "provider": name})
            return

        self._json_response({"status": "ok", "proxy": "codewiz", "provider": get_provider()})

    def _json_response(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        pass


def main():
    global VERBOSE, LOG_FILE, ADAPTER_SOURCE

    parser = argparse.ArgumentParser(description="CodeWiz LLM Proxy for Claude Code")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--log-file", metavar="FILE")
    parser.add_argument("--adapter-source", default="codewiz-cli",
                        help="x-adapter-source header value (default: codewiz-cli)")
    args = parser.parse_args()

    VERBOSE = args.debug
    ADAPTER_SOURCE = args.adapter_source
    if args.log_file:
        LOG_FILE = open(args.log_file, "a", encoding="utf-8")

    load_credentials()

    log("=" * 50)
    log(f"CodeWiz LLM Proxy 已启动 (adapter-source: {ADAPTER_SOURCE})")
    log(f"监听: http://127.0.0.1:{PORT}")
    log(f"目标: {TARGET_BASE_URL}")
    log(f"用户: {USER_EMAIL}")
    log("Model mappings:")
    for src, dst in sorted(MODEL_MAP.items()):
        log(f"  {src} -> {dst}")
    log("=" * 50)

    class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True

    server = ThreadingHTTPServer(("127.0.0.1", PORT), ProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("代理已停止")
        server.server_close()
        if LOG_FILE:
            LOG_FILE.close()


if __name__ == "__main__":
    main()
