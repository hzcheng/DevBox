#!/usr/bin/env python3

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "devbox" / "scripts"))

from codewiz_proxy import config  # noqa: E402


class KimiK3ProxyConfigTest(unittest.TestCase):
    def test_kimi_k3_is_openai_compatible(self) -> None:
        self.assertIn("kimi-k3", config.OPENAI_COMPAT_MODELS)

    def test_kimi3_alias_uses_codewiz_model_id(self) -> None:
        self.assertEqual(config.PREFIX_MODEL_ALIAS["kimi3"], "kimi-k3")


if __name__ == "__main__":
    unittest.main()
