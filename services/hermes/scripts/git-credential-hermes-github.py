#!/usr/bin/env python3
"""Provide the private Hermes GitHub token to Git's credential protocol."""

from __future__ import annotations

from pathlib import Path
import sys


ENV_PATH = Path("/opt/data/.env")


def read_token() -> str:
    try:
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return ""
    for line in lines:
        if line.startswith("GITHUB_TOKEN="):
            return line.partition("=")[2].strip()
    return ""


def main() -> int:
    operation = sys.argv[1] if len(sys.argv) > 1 else "get"
    if operation != "get":
        return 0

    request: dict[str, str] = {}
    for raw_line in sys.stdin:
        line = raw_line.rstrip("\r\n")
        if not line:
            break
        key, separator, value = line.partition("=")
        if separator:
            request[key] = value

    if request.get("protocol") != "https" or request.get("host") != "github.com":
        return 0

    token = read_token()
    if not token:
        return 1
    print("username=x-access-token")
    print(f"password={token}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
