#!/usr/bin/env python3
"""Run the bundled Hermes Google OAuth helper with Carron's limited scopes."""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path


SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events.owned",
]


def main() -> None:
    hermes_home = Path(os.environ.get("HERMES_HOME", "/opt/data"))
    setup_path = hermes_home / "skills/productivity/google-workspace/scripts/setup.py"
    if not setup_path.is_file():
        raise SystemExit(f"Bundled Google setup not found: {setup_path}")

    spec = importlib.util.spec_from_file_location("hermes_google_setup", setup_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load {setup_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.SCOPES = list(SCOPES)
    if sys.argv[1:] == ["--auth-code-stdin"]:
        callback_url = sys.stdin.readline().strip()
        if not callback_url:
            raise SystemExit("No OAuth callback URL received on standard input.")
        module.exchange_auth_code(callback_url)
        return
    module.main()


if __name__ == "__main__":
    main()
