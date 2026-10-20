#!/usr/bin/env python3
"""Limited Gmail drafts, owned-calendar events, and booking-link registry."""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import stat
import sys
from email.message import EmailMessage
from pathlib import Path
from urllib.parse import urlparse


HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/opt/data"))
TOKEN_PATH = HERMES_HOME / "google_token.json"
BOOKING_LINKS_PATH = HERMES_HOME / "google_booking_links.json"

GMAIL_READ = "https://www.googleapis.com/auth/gmail.readonly"
GMAIL_COMPOSE = "https://www.googleapis.com/auth/gmail.compose"
CALENDAR_READ = "https://www.googleapis.com/auth/calendar.readonly"
CALENDAR_OWNED = "https://www.googleapis.com/auth/calendar.events.owned"
EXPECTED_SCOPES = {GMAIL_READ, GMAIL_COMPOSE, CALENDAR_READ, CALENDAR_OWNED}


def _json(data: object) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False))


def _token_payload() -> dict:
    if not TOKEN_PATH.is_file():
        raise SystemExit("Google OAuth token missing. Run the limited OAuth setup first.")
    return json.loads(TOKEN_PATH.read_text(encoding="utf-8"))


def _scopes() -> set[str]:
    payload = _token_payload()
    raw = payload.get("scopes", [])
    if isinstance(raw, str):
        raw = raw.split()
    return {str(scope) for scope in raw}


def _require_scopes(*required: str) -> None:
    missing = set(required) - _scopes()
    if missing:
        raise SystemExit("Missing OAuth scopes: " + ", ".join(sorted(missing)))


def _service(api: str, version: str):
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    payload = _token_payload()
    scopes = sorted(_scopes())
    credentials = Credentials.from_authorized_user_info(payload, scopes=scopes)
    if credentials.expired and credentials.refresh_token:
        credentials.refresh(Request())
        refreshed = json.loads(credentials.to_json())
        refreshed["scopes"] = scopes
        TOKEN_PATH.write_text(json.dumps(refreshed, indent=2), encoding="utf-8")
        os.chmod(TOKEN_PATH, stat.S_IRUSR | stat.S_IWUSR)
    if not credentials.valid:
        raise SystemExit("Google OAuth token is invalid; reauthorize Hermes.")
    return build(api, version, credentials=credentials, cache_discovery=False)


def _body(args: argparse.Namespace) -> str:
    if getattr(args, "body_file", None):
        return Path(args.body_file).read_text(encoding="utf-8")
    return args.body


def _validate_addresses(value: str) -> str:
    addresses = [item.strip() for item in value.split(",") if item.strip()]
    if not addresses:
        raise SystemExit("At least one email address is required.")
    simple_email = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
    for address in addresses:
        if not simple_email.match(address):
            raise SystemExit(f"Invalid email address: {address}")
    return ", ".join(addresses)


def _mime(args: argparse.Namespace) -> str:
    message = EmailMessage()
    message["To"] = _validate_addresses(args.to)
    message["Subject"] = args.subject
    if args.cc:
        message["Cc"] = _validate_addresses(args.cc)
    if args.bcc:
        message["Bcc"] = _validate_addresses(args.bcc)
    body = _body(args)
    if args.html:
        message.set_content("Ce brouillon contient une version HTML.")
        message.add_alternative(body, subtype="html")
    else:
        message.set_content(body)
    return base64.urlsafe_b64encode(message.as_bytes()).decode("ascii")


def draft_create(args: argparse.Namespace) -> None:
    _require_scopes(GMAIL_COMPOSE)
    result = _service("gmail", "v1").users().drafts().create(
        userId="me", body={"message": {"raw": _mime(args)}}
    ).execute()
    _json({"status": "draft_created", "id": result["id"], "messageId": result.get("message", {}).get("id", "")})


def draft_update(args: argparse.Namespace) -> None:
    _require_scopes(GMAIL_COMPOSE)
    result = _service("gmail", "v1").users().drafts().update(
        userId="me", id=args.draft_id, body={"message": {"raw": _mime(args)}}
    ).execute()
    _json({"status": "draft_updated", "id": result["id"], "messageId": result.get("message", {}).get("id", "")})


def draft_list(args: argparse.Namespace) -> None:
    _require_scopes(GMAIL_COMPOSE)
    gmail = _service("gmail", "v1")
    response = gmail.users().drafts().list(userId="me", maxResults=args.max).execute()
    rows = []
    for item in response.get("drafts", []):
        draft = gmail.users().drafts().get(userId="me", id=item["id"], format="metadata").execute()
        message = draft.get("message", {})
        headers = {
            header.get("name", "").lower(): header.get("value", "")
            for header in message.get("payload", {}).get("headers", [])
        }
        rows.append({
            "id": draft["id"],
            "messageId": message.get("id", ""),
            "to": headers.get("to", ""),
            "subject": headers.get("subject", ""),
            "snippet": message.get("snippet", ""),
        })
    _json(rows)


def draft_delete(args: argparse.Namespace) -> None:
    if not args.confirm_delete:
        raise SystemExit("Refusing deletion without --confirm-delete.")
    _require_scopes(GMAIL_COMPOSE)
    _service("gmail", "v1").users().drafts().delete(userId="me", id=args.draft_id).execute()
    _json({"status": "draft_deleted", "id": args.draft_id})


def calendar_list(args: argparse.Namespace) -> None:
    _require_scopes(CALENDAR_READ)
    response = _service("calendar", "v3").events().list(
        calendarId=args.calendar,
        timeMin=args.start,
        timeMax=args.end,
        maxResults=args.max,
        singleEvents=True,
        orderBy="startTime",
    ).execute()
    rows = []
    for event in response.get("items", []):
        rows.append({
            "id": event["id"],
            "summary": event.get("summary", "(sans titre)"),
            "start": event.get("start", {}).get("dateTime", event.get("start", {}).get("date", "")),
            "end": event.get("end", {}).get("dateTime", event.get("end", {}).get("date", "")),
            "location": event.get("location", ""),
            "description": event.get("description", ""),
            "htmlLink": event.get("htmlLink", ""),
        })
    _json(rows)


def _event_payload(args: argparse.Namespace, partial: bool = False) -> dict:
    event: dict = {}
    for name in ("summary", "location", "description"):
        value = getattr(args, name, None)
        if value is not None:
            event[name] = value
    if getattr(args, "start", None) is not None:
        event["start"] = {"dateTime": args.start}
    if getattr(args, "end", None) is not None:
        event["end"] = {"dateTime": args.end}
    if getattr(args, "attendees", None) is not None:
        event["attendees"] = [{"email": email.strip()} for email in args.attendees.split(",") if email.strip()]
    if not partial and not {"summary", "start", "end"}.issubset(event):
        raise SystemExit("summary, start and end are required to create an event.")
    if partial and not event:
        raise SystemExit("At least one event field must be supplied.")
    return event


def calendar_create(args: argparse.Namespace) -> None:
    _require_scopes(CALENDAR_OWNED)
    result = _service("calendar", "v3").events().insert(
        calendarId=args.calendar, body=_event_payload(args), sendUpdates="none"
    ).execute()
    _json({"status": "event_created", "id": result["id"], "htmlLink": result.get("htmlLink", "")})


def calendar_update(args: argparse.Namespace) -> None:
    _require_scopes(CALENDAR_OWNED)
    result = _service("calendar", "v3").events().patch(
        calendarId=args.calendar,
        eventId=args.event_id,
        body=_event_payload(args, partial=True),
        sendUpdates="none",
    ).execute()
    _json({"status": "event_updated", "id": result["id"], "htmlLink": result.get("htmlLink", "")})


def calendar_delete(args: argparse.Namespace) -> None:
    if not args.confirm_delete:
        raise SystemExit("Refusing deletion without --confirm-delete.")
    _require_scopes(CALENDAR_OWNED)
    _service("calendar", "v3").events().delete(
        calendarId=args.calendar, eventId=args.event_id, sendUpdates="none"
    ).execute()
    _json({"status": "event_deleted", "id": args.event_id})


def _load_links() -> dict[str, str]:
    if not BOOKING_LINKS_PATH.exists():
        return {}
    payload = json.loads(BOOKING_LINKS_PATH.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise SystemExit("Booking-link registry is invalid.")
    return {str(name): str(url) for name, url in payload.items()}


def _save_links(links: dict[str, str]) -> None:
    BOOKING_LINKS_PATH.write_text(json.dumps(links, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.chmod(BOOKING_LINKS_PATH, stat.S_IRUSR | stat.S_IWUSR)


def booking_list(_: argparse.Namespace) -> None:
    _json(_load_links())


def booking_add(args: argparse.Namespace) -> None:
    parsed = urlparse(args.url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise SystemExit("A valid https booking URL is required.")
    links = _load_links()
    links[args.name] = args.url
    _save_links(links)
    _json({"status": "booking_link_saved", "name": args.name, "url": args.url})


def booking_remove(args: argparse.Namespace) -> None:
    if not args.confirm_delete:
        raise SystemExit("Refusing removal without --confirm-delete.")
    links = _load_links()
    if args.name not in links:
        raise SystemExit(f"Unknown booking link: {args.name}")
    del links[args.name]
    _save_links(links)
    _json({"status": "booking_link_removed", "name": args.name})


def self_check(_: argparse.Namespace) -> None:
    source = Path(__file__).read_text(encoding="utf-8")
    forbidden = ["messages()" + ".send(", "add_parser(" + '"send")', "gmail " + "send"]
    found = [item for item in forbidden if item in source]
    if found:
        raise SystemExit("Forbidden send capability found: " + ", ".join(found))
    _json({"status": "ok", "send_capability": False, "expected_scopes": sorted(EXPECTED_SCOPES)})


def _message_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--to", required=True)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--body", default="")
    parser.add_argument("--body-file")
    parser.add_argument("--cc")
    parser.add_argument("--bcc")
    parser.add_argument("--html", action="store_true")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="resource", required=True)

    gmail = sub.add_parser("gmail")
    gmail_sub = gmail.add_subparsers(dest="action", required=True)
    command = gmail_sub.add_parser("draft-create")
    _message_args(command)
    command.set_defaults(func=draft_create)
    command = gmail_sub.add_parser("draft-update")
    command.add_argument("draft_id")
    _message_args(command)
    command.set_defaults(func=draft_update)
    command = gmail_sub.add_parser("draft-list")
    command.add_argument("--max", type=int, default=20)
    command.set_defaults(func=draft_list)
    command = gmail_sub.add_parser("draft-delete")
    command.add_argument("draft_id")
    command.add_argument("--confirm-delete", action="store_true")
    command.set_defaults(func=draft_delete)

    calendar = sub.add_parser("calendar")
    calendar_sub = calendar.add_subparsers(dest="action", required=True)
    command = calendar_sub.add_parser("list")
    command.add_argument("--start", required=True, help="ISO 8601 timestamp with timezone")
    command.add_argument("--end", required=True, help="ISO 8601 timestamp with timezone")
    command.add_argument("--max", type=int, default=50)
    command.add_argument("--calendar", default="primary")
    command.set_defaults(func=calendar_list)
    command = calendar_sub.add_parser("create")
    command.add_argument("--summary", required=True)
    command.add_argument("--start", required=True)
    command.add_argument("--end", required=True)
    command.add_argument("--location")
    command.add_argument("--description")
    command.add_argument("--attendees")
    command.add_argument("--calendar", default="primary")
    command.set_defaults(func=calendar_create)
    command = calendar_sub.add_parser("update")
    command.add_argument("event_id")
    command.add_argument("--summary")
    command.add_argument("--start")
    command.add_argument("--end")
    command.add_argument("--location")
    command.add_argument("--description")
    command.add_argument("--attendees")
    command.add_argument("--calendar", default="primary")
    command.set_defaults(func=calendar_update)
    command = calendar_sub.add_parser("delete")
    command.add_argument("event_id")
    command.add_argument("--calendar", default="primary")
    command.add_argument("--confirm-delete", action="store_true")
    command.set_defaults(func=calendar_delete)

    booking = sub.add_parser("booking")
    booking_sub = booking.add_subparsers(dest="action", required=True)
    command = booking_sub.add_parser("list")
    command.set_defaults(func=booking_list)
    command = booking_sub.add_parser("add")
    command.add_argument("name")
    command.add_argument("url")
    command.set_defaults(func=booking_add)
    command = booking_sub.add_parser("remove")
    command.add_argument("name")
    command.add_argument("--confirm-delete", action="store_true")
    command.set_defaults(func=booking_remove)

    command = sub.add_parser("self-check")
    command.set_defaults(func=self_check)

    args = parser.parse_args()
    if getattr(args, "body_file", None) and args.body:
        parser.error("Use either --body or --body-file, not both.")
    args.func(args)


if __name__ == "__main__":
    main()
