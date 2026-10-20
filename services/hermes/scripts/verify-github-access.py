#!/usr/bin/env python3
"""Verify authenticated GitHub access without printing the token."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ENV_PATH = Path("/opt/data/.env")
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


def read_token() -> str:
    try:
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return ""
    for line in lines:
        if line.startswith("GITHUB_TOKEN="):
            return line.partition("=")[2].strip()
    return ""


def github_get(path: str, token: str) -> dict:
    request = Request(
        f"https://api.github.com{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "autostack-hermes-github-check",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urlopen(request, timeout=20) as response:
        return json.load(response)


def main() -> int:
    repositories = sys.argv[1:]
    if not repositories or any(not REPOSITORY_PATTERN.fullmatch(repo) for repo in repositories):
        print("Usage: verify-github-access.py OWNER/REPO [OWNER/REPO ...]", file=sys.stderr)
        return 2

    token = read_token()
    if not token:
        print("GITHUB_TOKEN_MISSING", file=sys.stderr)
        return 2

    try:
        account = github_get("/user", token)
        print(f"GITHUB_ACCOUNT={account.get('login', 'unknown')}")
        failures = 0
        for repository in repositories:
            details = github_get(f"/repos/{repository}", token)
            permissions = details.get("permissions") or {}
            can_pull = bool(permissions.get("pull"))
            can_push = bool(permissions.get("push"))
            print(f"GITHUB_REPOSITORY={repository} pull={str(can_pull).lower()} push={str(can_push).lower()}")
            if not can_pull or not can_push:
                failures += 1
        return 1 if failures else 0
    except HTTPError as exc:
        print(f"GITHUB_API_ERROR={exc.code}", file=sys.stderr)
        return 1
    except (URLError, TimeoutError) as exc:
        print(f"GITHUB_NETWORK_ERROR={type(exc).__name__}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
