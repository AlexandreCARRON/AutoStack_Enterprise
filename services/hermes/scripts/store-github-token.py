#!/usr/bin/env python3
"""Store a GitHub token received on stdin without printing it."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys
import tempfile


ENV_PATH = Path("/opt/data/.env")
TOKEN_PATTERN = re.compile(r"^(?:github_pat_|ghp_)[A-Za-z0-9_]+$")
TOKEN_KEYS = ("GITHUB_TOKEN=", "GH_TOKEN=")


def main() -> int:
    token = sys.stdin.read(1024).strip()
    if not TOKEN_PATTERN.fullmatch(token):
        print("Invalid GitHub token format.", file=sys.stderr)
        return 2

    try:
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        lines = []

    lines = [line for line in lines if not line.startswith(TOKEN_KEYS)]
    lines.append(f"GITHUB_TOKEN={token}")
    ENV_PATH.parent.mkdir(parents=True, exist_ok=True)

    fd, temporary_name = tempfile.mkstemp(
        prefix=".github-env-", dir=ENV_PATH.parent, text=True
    )
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
        os.replace(temporary_name, ENV_PATH)
        os.chmod(ENV_PATH, 0o600)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise

    print("GITHUB_TOKEN_STORED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
