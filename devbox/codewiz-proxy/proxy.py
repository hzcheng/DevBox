#!/usr/bin/env python3
"""
CodeWiz LLM Proxy for Claude Code
将 Claude Code 的请求转发到公司 CodeWiz LLM Adapter 端点。

所有配置均通过环境变量注入，不含任何硬编码的认证信息。

必须的环境变量:
  CODEWIZ_SESSION_TOKEN  - SSO session token（从 VS Code 开发者工具获取）
  CODEWIZ_USER_EMAIL     - 你的公司邮箱

可选的环境变量:
  CODEWIZ_TARGET_URL     - CodeWiz 后端地址（默认: https://codewiz.devops.xiaohongshu.com/llmadapter/claude）
  CODEWIZ_API_KEY        - API Key（默认: CodeWiz 公共 key）
  CODEWIZ_PROXY_PORT     - 代理监听端口（默认: 8088）

用法:
  python3 proxy.py [--debug] [--log-file FILE]
"""

import argparse
import http.server
import json
import os
import ssl
import sys
import urllib.request
import urllib.error
import time
from datetime import datetime

TARGET_BASE_URL = os.environ.get("CODEWIZ_TARGET_URL", "https://codewiz.devops.xiaohongshu.com/llmadapter/claude")
API_KEY = os.environ.get("CODEWIZ_API_KEY", "QST2332f67caa6bdce8ae9fbd3524bdf2fa")
USER_EMAIL = os.environ.get("CODEWIZ_USER_EMAIL", "")
SESSION_TOKEN = os.environ.get("CODEWIZ_SESSION_TOKEN", "")
PORT = int(os.environ.get("CODEWIZ_PROXY_PORT", "8088"))

# Claude Code 发送的模型名 → CodeWiz 后端实际模型名
MODEL_MAP = {
    "claude-sonnet-4-5-20250514": "claude-4.6-opus-google",
    # 可以按需添加更多映射
}

# CodeWiz 后端不支持的 anthropic-beta 值，需要过滤掉
UNSUPPORTED_BETAS = {
    "prompt-caching-scope-2026-01-05",
    "redact-thinking-2026-02-12",
}

REQ_COUNT = 0
VERBOSE = False
LOG_FILE = None


def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    if LOG_FILE:
        LOG_FILE.write(line + "\n")
        LOG_FILE.flush()


class StreamingProxyHandler(http.server.BaseHTTPRequestHandler):
    """处理 Claude Code 的 API 请求并转发到 CodeWiz 后端"""

    def do_POST(self):
        global REQ_COUNT
        REQ_COUNT += 1
        req_id = REQ_COUNT

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        # ---- 基本请求信息（始终打印）----
        log(f"{'='*50}")
        log(f"📥 请求 #{req_id}  {self.command} {self.path}")

        try:
            body_json = json.loads(body)

            # ---- 模型名映射 ----
            original_model = body_json.get("model", "")
            if original_model in MODEL_MAP:
                body_json["model"] = MODEL_MAP[original_model]
                log(f"  🔄 模型映射: {original_model} → {body_json['model']}")
                body = json.dumps(body_json).encode("utf-8")

            # 简要摘要（始终打印）
            log(f"  model: {body_json.get('model', 'N/A')}  stream: {body_json.get('stream', 'N/A')}  messages: {len(body_json.get('messages', []))} 条")

            # ---- verbose 模式：打印完整 headers 和 body ----
            if VERBOSE:
                log(f"--- Headers ---")
                for key, value in self.headers.items():
                    if key.lower() in ("x-api-key", "authorization", "cookie"):
                        log(f"  {key}: ***")
                    else:
                        log(f"  {key}: {value}")
                log(f"--- Body ---")
                log(json.dumps(body_json, indent=2, ensure_ascii=False))

        except (json.JSONDecodeError, KeyError):
            log(f"  [body 解析失败, 长度: {len(body)} bytes]")
            if VERBOSE:
                log(body.decode("utf-8", errors="replace"))

        # ---- 构建转发请求 ----
        target_url = TARGET_BASE_URL + self.path
        req = urllib.request.Request(target_url, data=body, method="POST")

        # 转发原始 headers（过滤不支持的 anthropic-beta 值）
        skip_headers = {"host", "content-length", "transfer-encoding", "connection"}
        for key, value in self.headers.items():
            if key.lower() not in skip_headers:
                if key.lower() == "anthropic-beta":
                    betas = [b.strip() for b in value.split(",")]
                    filtered = [b for b in betas if b not in UNSUPPORTED_BETAS]
                    if filtered:
                        req.add_header(key, ", ".join(filtered))
                        if len(filtered) != len(betas):
                            log(f"  🔧 过滤 anthropic-beta: {value} → {', '.join(filtered)}")
                    else:
                        log(f"  🔧 移除 anthropic-beta header（全部不支持）")
                    continue
                req.add_header(key, value)

        # 注入 CodeWiz 认证 headers
        req.add_header("Cookie", f"common-internal-access-token-prod={SESSION_TOKEN};")
        req.add_header("user-email", USER_EMAIL)
        req.add_header("X-Adapter-User-Email", USER_EMAIL)
        req.add_header("X-Adapter-Source", "rednote-codewiz")
        req.add_header("task-id", f"claude-code-{int(time.time())}")

        ctx = ssl.create_default_context()
        start_time = time.time()

        try:
            resp = urllib.request.urlopen(req, context=ctx, timeout=600)
            elapsed = time.time() - start_time
            log(f"📤 响应 #{req_id}  {resp.status} ({elapsed:.1f}s)")

            self.send_response(resp.status)
            for key, value in resp.getheaders():
                if key.lower() not in ("transfer-encoding", "connection"):
                    self.send_header(key, value)
            self.end_headers()

            # 流式转发
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()

        except urllib.error.HTTPError as e:
            elapsed = time.time() - start_time
            error_body = e.read()
            log(f"❌ 错误 #{req_id}  {e.code} ({elapsed:.1f}s)")
            log(f"  {error_body.decode('utf-8', errors='replace')[:500]}")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(error_body)

        except Exception as e:
            elapsed = time.time() - start_time
            log(f"❌ 异常 #{req_id}  ({elapsed:.1f}s): {e}")
            error_msg = json.dumps({"error": str(e)}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(error_msg)

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok", "proxy": "codewiz"}).encode())

    def log_message(self, format, *args):
        pass  # 禁用默认日志，用自定义的


def main():
    global VERBOSE, LOG_FILE

    parser = argparse.ArgumentParser(description="CodeWiz LLM Proxy for Claude Code")
    parser.add_argument("--debug", action="store_true",
                        help="调试模式：打印完整的请求 headers 和 body")
    parser.add_argument("--log-file", metavar="FILE",
                        help="将日志同时输出到指定文件")
    args = parser.parse_args()

    VERBOSE = args.debug

    if args.log_file:
        LOG_FILE = open(args.log_file, "a", encoding="utf-8")

    missing = []
    if not SESSION_TOKEN:
        missing.append("CODEWIZ_SESSION_TOKEN")
    if not USER_EMAIL:
        missing.append("CODEWIZ_USER_EMAIL")
    if missing:
        print("=" * 60)
        print(f"错误: 未设置必要的环境变量: {', '.join(missing)}")
        print()
        print("请在 ~/.zshrc 中配置（参考 README.md）:")
        print('  export CODEWIZ_SESSION_TOKEN="AT-xxx"')
        print('  export CODEWIZ_USER_EMAIL="yourname@xiaohongshu.com"')
        print()
        print("Session Token 获取方法:")
        print("  1. VS Code 中 Cmd+Shift+P → Developer: Toggle Developer Tools")
        print("  2. Network 标签页 → 在 CodeWiz 中发消息")
        print("  3. 找到 codewiz.devops.xiaohongshu.com 请求的 Accesstoken header")
        print("=" * 60)
        sys.exit(1)

    server = http.server.HTTPServer(("127.0.0.1", PORT), StreamingProxyHandler)
    log("=" * 50)
    log("CodeWiz LLM Proxy 已启动")
    log(f"监听: http://127.0.0.1:{PORT}")
    log(f"目标: {TARGET_BASE_URL}")
    log(f"用户: {USER_EMAIL}")
    log(f"调试模式: {'开启' if VERBOSE else '关闭'} (--debug 开启)")
    if LOG_FILE:
        log(f"日志文件: {args.log_file}")
    log("=" * 50)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("代理已停止")
        server.server_close()
        if LOG_FILE:
            LOG_FILE.close()


if __name__ == "__main__":
    main()
