"""
codewiz-proxy.py — CodeWiz LLM Proxy 入口

实现在 codewiz_proxy/ 包中，见同目录下各模块。
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from codewiz_proxy.server import main

if __name__ == "__main__":
    main()
