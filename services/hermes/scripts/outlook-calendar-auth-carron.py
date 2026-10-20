#!/usr/bin/env python3
"""Microsoft Graph device-code OAuth for the limited Hermes Outlook calendar skill."""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))
CONFIG_PATH = HERMES_HOME / "outlook_calendar_config.json"
TOKEN_PATH = HERMES_HOME / "outlook_calendar_token.json"
GRAPH_BASE = "https://graph.microsoft.com/v1.0"
SCOPES = ["offline_access", "Calendars.ReadWrite"]
TENANT_PATTERN = re.compile(r"^(common|consumers|organizations|[0-9a-fA-F-]{36})$")
CLIENT_ID_PATTERN = re.compile(r"^[0-9a-fA-F-]{36}$")


class OAuthError(RuntimeError):
    pass


def _private_write(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)


def _json_request(method: str, url: str, *, form: dict | None = None, token: str | None = None, body: dict | None = None) -> dict:
    headers = {"Accept": "application/json"}
    data = None
    if form is not None:
        data = urllib.parse.urlencode(form).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    elif body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            detail = json.loads(raw)
        except json.JSONDecodeError:
            detail = {"error": raw or exc.reason}
        raise OAuthError(f"HTTP {exc.code}: {detail}") from exc


def load_config() -> dict:
    if not CONFIG_PATH.is_file():
        raise SystemExit("Outlook config missing. Run configure with your Microsoft application client ID.")
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def configure(args: argparse.Namespace) -> None:
    if not CLIENT_ID_PATTERN.fullmatch(args.client_id):
        raise SystemExit("The Microsoft application client ID must be a UUID.")
    if not TENANT_PATTERN.fullmatch(args.tenant):
        raise SystemExit("Tenant must be common, consumers, organizations, or a tenant UUID.")
    _private_write(CONFIG_PATH, {
        "client_id": args.client_id,
        "tenant": args.tenant,
        "timezone": args.timezone,
        "scopes": SCOPES,
    })
    print(f"CONFIGURED {CONFIG_PATH}")


def _authority(config: dict) -> str:
    return f"https://login.microsoftonline.com/{config['tenant']}/oauth2/v2.0"


def _normalize_token(payload: dict, previous: dict | None = None) -> dict:
    token = dict(payload)
    if previous and not token.get("refresh_token"):
        token["refresh_token"] = previous.get("refresh_token")
    token["obtained_at"] = int(time.time())
    token["expires_at"] = int(time.time()) + int(token.get("expires_in", 3600))
    token["scopes"] = str(token.get("scope", " ".join(SCOPES))).split()
    return token


def login(_: argparse.Namespace) -> None:
    config = load_config()
    authority = _authority(config)
    device = _json_request("POST", f"{authority}/devicecode", form={
        "client_id": config["client_id"],
        "scope": " ".join(SCOPES),
    })
    print(device.get("message") or f"Open {device['verification_uri']} and enter code {device['user_code']}")
    print("Waiting for Microsoft authorization...")
    interval = int(device.get("interval", 5))
    deadline = time.time() + int(device.get("expires_in", 900))
    while time.time() < deadline:
        time.sleep(interval)
        try:
            token = _json_request("POST", f"{authority}/token", form={
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": config["client_id"],
                "device_code": device["device_code"],
            })
        except OAuthError as exc:
            message = str(exc)
            if "authorization_pending" in message:
                continue
            if "slow_down" in message:
                interval += 5
                continue
            raise SystemExit(message) from exc
        _private_write(TOKEN_PATH, _normalize_token(token))
        print(f"AUTHENTICATED {TOKEN_PATH}")
        return
    raise SystemExit("Microsoft device code expired. Run login again.")


def _refresh(config: dict, token: dict) -> dict:
    refresh_token = token.get("refresh_token")
    if not refresh_token:
        raise SystemExit("Microsoft refresh token missing. Run login again.")
    refreshed = _json_request("POST", f"{_authority(config)}/token", form={
        "client_id": config["client_id"],
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "scope": " ".join(SCOPES),
    })
    normalized = _normalize_token(refreshed, token)
    _private_write(TOKEN_PATH, normalized)
    return normalized


def access_token() -> str:
    config = load_config()
    if not TOKEN_PATH.is_file():
        raise SystemExit("Outlook token missing. Run login first.")
    token = json.loads(TOKEN_PATH.read_text(encoding="utf-8"))
    if int(token.get("expires_at", 0)) <= int(time.time()) + 120:
        token = _refresh(config, token)
    granted = set(token.get("scopes", []))
    if "Calendars.ReadWrite" not in granted:
        raise SystemExit("Microsoft token does not include Calendars.ReadWrite.")
    return str(token["access_token"])


def graph_request(method: str, endpoint: str, *, body: dict | None = None) -> dict:
    return _json_request(method, f"{GRAPH_BASE}{endpoint}", token=access_token(), body=body)


def check(_: argparse.Namespace) -> None:
    calendar = graph_request("GET", "/me/calendar?$select=id,name")
    print(json.dumps({"status": "authenticated", "calendar": calendar.get("name", "primary")}, ensure_ascii=False))


def disconnect(args: argparse.Namespace) -> None:
    if not args.confirm_delete_local_token:
        raise SystemExit("Refusing local token deletion without --confirm-delete-local-token.")
    TOKEN_PATH.unlink(missing_ok=True)
    print("LOCAL_TOKEN_DELETED")


def self_check(_: argparse.Namespace) -> None:
    source = Path(__file__).read_text(encoding="utf-8")
    forbidden = ["Mail." + "Read", "Mail." + "Send", "/me/" + "messages"]
    found = [value for value in forbidden if value in source]
    if found or SCOPES != ["offline_access", "Calendars.ReadWrite"]:
        raise SystemExit("Outlook OAuth scope guard failed.")
    print(json.dumps({"status": "ok", "scopes": SCOPES, "mail_access": False}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    command = sub.add_parser("configure")
    command.add_argument("--client-id", required=True)
    command.add_argument("--tenant", default="common")
    command.add_argument("--timezone", default="Romance Standard Time")
    command.set_defaults(func=configure)
    command = sub.add_parser("login")
    command.set_defaults(func=login)
    command = sub.add_parser("check")
    command.set_defaults(func=check)
    command = sub.add_parser("disconnect")
    command.add_argument("--confirm-delete-local-token", action="store_true")
    command.set_defaults(func=disconnect)
    command = sub.add_parser("self-check")
    command.set_defaults(func=self_check)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
