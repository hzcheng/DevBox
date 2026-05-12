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
from .providers.kimi import get_token_ttl as kimi_token_ttl

ALLOWED_PROVIDERS = set(PROVIDER_REGISTRY.keys())


class ProxyHandler(http.server.BaseHTTPRequestHandler):

    def _is_openai_path(self) -> bool:
        return self.path.startswith("/responses") or self.path.startswith("/v1/chat")

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

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

        provider_name = config.get_provider()
        provider = PROVIDER_REGISTRY.get(provider_name)

        if provider is None:
            log(f"  [error] 未知 provider: {provider_name}")
            self._json_response({"error": f"unknown provider: {provider_name}"}, status=500)
            return

        if self._is_openai_path():
            provider.handle_openai(self, body)
        else:
            provider.handle_anthropic(self, body)

    def do_GET(self):
        if self.path in ("/api/hello", "/v1/oauth/hello"):
            self._json_response({"status": "ok"})
            return

        if self.path == "/admin/status":
            provider_name = config.get_provider()
            info = {"provider": provider_name, "port": config.PORT}
            if provider_name == "kimi":
                info["kimi_token_ttl_seconds"] = kimi_token_ttl()
            else:
                info["codewiz_user"] = credentials.USER_EMAIL
            self._json_response(info)
            return

        if self.path.startswith("/admin/switch"):
            qs = parse_qs(urlparse(self.path).query)
            name = (qs.get("provider") or [""])[0].strip()
            if name not in ALLOWED_PROVIDERS:
                self._json_response(
                    {"error": f"unknown provider '{name}', allowed: {sorted(ALLOWED_PROVIDERS)}"},
                    status=400,
                )
                return
            config.set_provider(name)
            log(f"[admin] provider 切换为: {name}")
            self._json_response({"ok": True, "provider": name})
            return

        self._json_response({"status": "ok", "proxy": "codewiz", "provider": config.get_provider()})

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
