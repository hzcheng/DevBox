"""
proxy.py — CodeWiz LLM Proxy for Claude Code & Codex

凭据优先级:
  1. 环境变量 CODEWIZ_SESSION_TOKEN / CODEWIZ_USER_EMAIL
  2. 自动检测 ~/.local/share/codewiz/auth.json

可选环境变量:
  CODEWIZ_TARGET_URL        - Claude 后端（默认: https://codewiz.devops.xiaohongshu.com/llmadapter/v3/claude）
  CODEWIZ_OPENAI_TARGET_URL - OpenAI 后端（默认: https://codewiz.devops.xiaohongshu.com/llmratelimit/v3/openai/v1）
  CODEWIZ_PROXY_PORT        - 监听端口（默认: 8089）
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

# ── 凭据（启动时填充） ──
SESSION_TOKEN = ""
SSO_TOKEN_KEY = "common-internal-access-token-prod"
USER_EMAIL = ""
USER_INFO = {}


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

        if self._is_openai_path():
            self._do_openai_post(body)
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

    def _do_openai_post(self, body):
        """转发 OpenAI 格式请求（Codex CLI 使用）到内部 OpenAI endpoint"""
        try:
            body_json = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            body_json = {}

        model = body_json.get("model", "N/A")
        log(f"  [openai] model: {model}  path: {self.path}")
        if VERBOSE:
            log(json.dumps(body_json, indent=2, ensure_ascii=False))

        target_url = OPENAI_TARGET_BASE_URL + self.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        skip_headers = {"host", "content-length", "transfer-encoding", "connection",
                        "authorization"}
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
            body = json.dumps({"status": "ok"}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok", "proxy": "codewiz"}).encode())

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
