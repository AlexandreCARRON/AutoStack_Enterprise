import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUTH = load("outlook_auth", "outlook-calendar-auth-carron.py")
CALENDAR = load("outlook_calendar", "outlook-calendar-carron.py")


class OutlookCalendarCarronTests(unittest.TestCase):
    def test_scopes_are_calendar_only(self):
        self.assertEqual(AUTH.SCOPES, ["offline_access", "Calendars.ReadWrite"])
        self.assertFalse(any(scope.startswith("Mail.") for scope in AUTH.SCOPES))

    def test_attendees_require_confirmation(self):
        with self.assertRaises(SystemExit):
            CALENDAR._require_invitation_confirmation([{"emailAddress": {"address": "a@example.com"}}], False)
        CALENDAR._require_invitation_confirmation([{"emailAddress": {"address": "a@example.com"}}], True)
        CALENDAR._require_invitation_confirmation([], False)

    def test_event_endpoint_escapes_calendar_id(self):
        self.assertEqual(CALENDAR._event_endpoint("a/b", "/event"), "/me/calendars/a%2Fb/events/event")

    def test_wrappers_have_no_mail_api(self):
        for filename in ("outlook-calendar-auth-carron.py", "outlook-calendar-carron.py"):
            source = (ROOT / "scripts" / filename).read_text(encoding="utf-8")
            self.assertNotIn("/me/messages", source)
            self.assertNotIn("Mail.Send", source)


if __name__ == "__main__":
    unittest.main()
