from __future__ import annotations

import argparse
import http.server
import json
import socketserver
from urllib.parse import urlparse, parse_qs

from . import config, credentials
from .utils import log
from .credentials import load_credentials
from .providers import PROVIDER_REGISTRY

# 默认入口 provider，前缀路由在 handle_anthropic/handle_openai 内部做委托
_DEFAULT_PROVIDER = PROVIDER_REGISTRY["codewiz"]


class ProxyHandler(http.server.BaseHTTPRequestHandler):

    def _is_openai_path(self) -> bool:
        return self.path.startswith("/responses") or self.path.startswith("/v1/chat")

    def _handle_count_tokens(self, body: bytes) -> None:
        """codewiz 网关不支持 count_tokens，返回模拟响应避免 Claude Code 反复 404。"""
        try:
            body_json = json.loads(body)
            messages = body_json.get("messages", [])
            system = body_json.get("system", "")
            # 粗略估算：每 4 字符约 1 token（含 JSON 包装开销）
            total_chars = len(json.dumps(messages, ensure_ascii=False)) + len(json.dumps(system, ensure_ascii=False))
            estimated = max(1, total_chars // 4)
        except Exception:
            estimated = 1000
        self._json_response({"input_tokens": estimated})

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        # codewiz 网关不支持 count_tokens，直接返回模拟值
        if "count_tokens" in self.path:
            self._handle_count_tokens(body)
            return

        if self.path.startswith("/admin/set-key"):
            qs = parse_qs(urlparse(self.path).query)
            provider = (qs.get("provider") or [""])[0].strip()
            try:
                raw = json.loads(body).get("key", "")
                key = raw.strip() if isinstance(raw, str) else ""
            except (json.JSONDecodeError, ValueError, AttributeError):
                key = ""
            if not key:
                self._json_response({"error": "key 不能为空"}, status=400)
                return
            if provider == "cowork":
                config.save_cowork_api_key(key)
                log("[admin] cowork API key 已更新")
                self._json_response({"ok": True, "provider": "cowork"})
            else:
                self._json_response({"error": f"provider '{provider}' 不支持 set-key"}, status=400)
            return

        log("=" * 50)
        log(f"{self.command} {self.path}")

        if self._is_openai_path():
            _DEFAULT_PROVIDER.handle_openai(self, body, provider_registry=PROVIDER_REGISTRY)
        else:
            _DEFAULT_PROVIDER.handle_anthropic(self, body, provider_registry=PROVIDER_REGISTRY)

    def do_GET(self):
        if self.path in ("/api/hello", "/v1/oauth/hello"):
            self._json_response({"status": "ok"})
            return

        if self.path == "/admin/status":
            self._json_response({"port": config.PORT, "codewiz_user": credentials.USER_EMAIL})
            return

        self._json_response({"status": "ok", "proxy": "codewiz"})

    def _json_response(self, data: dict, status: int = 200) -> None:
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
    parser = argparse.ArgumentParser(description="CodeWiz LLM Proxy for Claude Code")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--log-file", metavar="FILE")
    parser.add_argument("--adapter-source", default="codewiz-cli",
                        help="x-adapter-source header value (default: codewiz-cli)")
    args = parser.parse_args()

    config.VERBOSE = args.debug
    config.ADAPTER_SOURCE = args.adapter_source
    if args.log_file:
        config.LOG_FILE = open(args.log_file, "a", encoding="utf-8")

    load_credentials()

    log("=" * 50)
    log(f"CodeWiz LLM Proxy 已启动 (adapter-source: {config.ADAPTER_SOURCE})")
    log(f"监听: http://127.0.0.1:{config.PORT}")
    log(f"目标: {config.TARGET_BASE_URL}")
    log(f"用户: {credentials.USER_EMAIL}")
    if not config.OPENAI_COMPAT_API_KEY_VALUE:
        log("[warn] CODEWIZ_OPENAI_COMPAT_API_KEY 未设置，第三方 OpenAI 兼容模型（DeepSeek/Kimi/GLM/dots）将无法使用")
    log("Model mappings:")
    for src, dst in sorted(config.MODEL_MAP.items()):
        log(f"  {src} -> {dst}")
    log("=" * 50)

    class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True

    server = ThreadingHTTPServer(("127.0.0.1", config.PORT), ProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("代理已停止")
        server.server_close()
        if config.LOG_FILE:
            config.LOG_FILE.close()
