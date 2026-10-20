#!/usr/bin/env python3
"""Limited Microsoft Outlook calendar operations for Hermes."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
from urllib.parse import quote, urlencode


AUTH_SCRIPT = Path(__file__).with_name("outlook-calendar-auth-carron.py")


def _load_auth():
    spec = importlib.util.spec_from_file_location("outlook_calendar_auth_carron", AUTH_SCRIPT)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load {AUTH_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUTH = _load_auth()


def _json(data: object) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False))


def _event_endpoint(calendar_id: str | None, suffix: str = "") -> str:
    if calendar_id:
        return f"/me/calendars/{quote(calendar_id, safe='')}/events{suffix}"
    return f"/me/events{suffix}"


def calendars_list(_: argparse.Namespace) -> None:
    result = AUTH.graph_request("GET", "/me/calendars?$select=id,name,canEdit,isDefaultCalendar")
    _json([{
        "id": row.get("id", ""),
        "name": row.get("name", ""),
        "canEdit": row.get("canEdit", False),
        "isDefault": row.get("isDefaultCalendar", False),
    } for row in result.get("value", [])])


def events_list(args: argparse.Namespace) -> None:
    params = urlencode({
        "startDateTime": args.start,
        "endDateTime": args.end,
        "$select": "id,subject,start,end,location,bodyPreview,isAllDay,attendees,webLink",
        "$orderby": "start/dateTime",
        "$top": args.max,
    })
    if args.calendar:
        endpoint = f"/me/calendars/{quote(args.calendar, safe='')}/calendarView?{params}"
    else:
        endpoint = f"/me/calendarView?{params}"
    result = AUTH.graph_request("GET", endpoint)
    rows = []
    for event in result.get("value", []):
        rows.append({
            "id": event.get("id", ""),
            "subject": event.get("subject", "(sans titre)"),
            "start": event.get("start", {}),
            "end": event.get("end", {}),
            "location": event.get("location", {}).get("displayName", ""),
            "preview": event.get("bodyPreview", ""),
            "isAllDay": event.get("isAllDay", False),
            "attendees": [item.get("emailAddress", {}).get("address", "") for item in event.get("attendees", [])],
            "webLink": event.get("webLink", ""),
        })
    _json(rows)


def _attendees(raw: str | None) -> list[dict]:
    if not raw:
        return []
    return [{"emailAddress": {"address": email.strip()}, "type": "required"} for email in raw.split(",") if email.strip()]


def _require_invitation_confirmation(attendees: list, confirmed: bool) -> None:
    if attendees and not confirmed:
        raise SystemExit("Attendees may receive invitations or updates; add --confirm-notify-attendees after explicit user approval.")


def _event_payload(args: argparse.Namespace, *, partial: bool = False) -> dict:
    config = AUTH.load_config()
    timezone = config.get("timezone", "Romance Standard Time")
    payload: dict = {}
    if getattr(args, "subject", None) is not None:
        payload["subject"] = args.subject
    if getattr(args, "start", None) is not None:
        payload["start"] = {"dateTime": args.start, "timeZone": timezone}
    if getattr(args, "end", None) is not None:
        payload["end"] = {"dateTime": args.end, "timeZone": timezone}
    if getattr(args, "body", None) is not None:
        payload["body"] = {"contentType": "text", "content": args.body}
    if getattr(args, "location", None) is not None:
        payload["location"] = {"displayName": args.location}
    if getattr(args, "attendees", None) is not None:
        payload["attendees"] = _attendees(args.attendees)
    if not partial and not {"subject", "start", "end"}.issubset(payload):
        raise SystemExit("subject, start and end are required.")
    if partial and not payload:
        raise SystemExit("At least one event field must be supplied.")
    return payload


def event_create(args: argparse.Namespace) -> None:
    attendees = _attendees(args.attendees)
    _require_invitation_confirmation(attendees, args.confirm_notify_attendees)
    payload = _event_payload(args)
    result = AUTH.graph_request("POST", _event_endpoint(args.calendar), body=payload)
    _json({"status": "event_created", "id": result.get("id", ""), "webLink": result.get("webLink", "")})


def _existing_event(event_id: str, calendar_id: str | None) -> dict:
    endpoint = _event_endpoint(calendar_id, f"/{quote(event_id, safe='')}?$select=id,attendees,subject")
    return AUTH.graph_request("GET", endpoint)


def event_update(args: argparse.Namespace) -> None:
    existing = _existing_event(args.event_id, args.calendar)
    attendees = list(existing.get("attendees", [])) + _attendees(args.attendees)
    _require_invitation_confirmation(attendees, args.confirm_notify_attendees)
    endpoint = _event_endpoint(args.calendar, f"/{quote(args.event_id, safe='')}")
    result = AUTH.graph_request("PATCH", endpoint, body=_event_payload(args, partial=True))
    _json({"status": "event_updated", "id": result.get("id", args.event_id), "webLink": result.get("webLink", "")})


def event_delete(args: argparse.Namespace) -> None:
    if not args.confirm_delete:
        raise SystemExit("Refusing deletion without --confirm-delete.")
    existing = _existing_event(args.event_id, args.calendar)
    _require_invitation_confirmation(existing.get("attendees", []), args.confirm_notify_attendees)
    endpoint = _event_endpoint(args.calendar, f"/{quote(args.event_id, safe='')}")
    AUTH.graph_request("DELETE", endpoint)
    _json({"status": "event_deleted", "id": args.event_id})


def self_check(_: argparse.Namespace) -> None:
    source = Path(__file__).read_text(encoding="utf-8")
    forbidden = ["/me/" + "messages", "Mail." + "Send", "send" + "Mail"]
    if any(value in source for value in forbidden):
        raise SystemExit("Mail capability found in Outlook calendar wrapper.")
    _json({"status": "ok", "mail_access": False, "delete_confirmation": True, "attendee_confirmation": True})


def _event_fields(parser: argparse.ArgumentParser, *, required: bool) -> None:
    parser.add_argument("--subject", required=required)
    parser.add_argument("--start", required=required, help="Local ISO timestamp, for example 2026-10-07T14:00:00")
    parser.add_argument("--end", required=required, help="Local ISO timestamp, for example 2026-10-07T14:30:00")
    parser.add_argument("--body")
    parser.add_argument("--location")
    parser.add_argument("--attendees")
    parser.add_argument("--calendar")
    parser.add_argument("--confirm-notify-attendees", action="store_true")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="resource", required=True)
    calendars = sub.add_parser("calendars")
    calendar_sub = calendars.add_subparsers(dest="action", required=True)
    command = calendar_sub.add_parser("list")
    command.set_defaults(func=calendars_list)
    events = sub.add_parser("events")
    event_sub = events.add_subparsers(dest="action", required=True)
    command = event_sub.add_parser("list")
    command.add_argument("--start", required=True)
    command.add_argument("--end", required=True)
    command.add_argument("--calendar")
    command.add_argument("--max", type=int, default=50)
    command.set_defaults(func=events_list)
    command = event_sub.add_parser("create")
    _event_fields(command, required=True)
    command.set_defaults(func=event_create)
    command = event_sub.add_parser("update")
    command.add_argument("event_id")
    _event_fields(command, required=False)
    command.set_defaults(func=event_update)
    command = event_sub.add_parser("delete")
    command.add_argument("event_id")
    command.add_argument("--calendar")
    command.add_argument("--confirm-delete", action="store_true")
    command.add_argument("--confirm-notify-attendees", action="store_true")
    command.set_defaults(func=event_delete)
    command = sub.add_parser("self-check")
    command.set_defaults(func=self_check)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
