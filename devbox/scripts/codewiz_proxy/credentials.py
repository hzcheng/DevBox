from __future__ import annotations

import base64
import json
import os
import sys

from .utils import log

SESSION_TOKEN: str = ""
SSO_TOKEN_KEY: str = "common-internal-access-token-prod"
USER_EMAIL: str = ""
USER_INFO: dict = {}


def _read_token_from_auth_json() -> str | None:
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


def _auto_detect_credentials() -> dict | None:
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


def load_credentials() -> None:
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
