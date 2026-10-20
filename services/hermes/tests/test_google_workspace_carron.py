import importlib.util
import unittest
from argparse import Namespace
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts/google-workspace-carron.py"
SPEC = importlib.util.spec_from_file_location("google_workspace_carron", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GoogleWorkspaceCarronTests(unittest.TestCase):
    def test_wrapper_has_no_send_capability(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("messages().send(", source)
        self.assertNotIn('add_parser("send")', source)
        self.assertNotIn("gmail send", source)

    def test_expected_scopes_are_limited(self):
        self.assertEqual(
            MODULE.EXPECTED_SCOPES,
            {
                MODULE.GMAIL_READ,
                MODULE.GMAIL_COMPOSE,
                MODULE.CALENDAR_READ,
                MODULE.CALENDAR_OWNED,
            },
        )
        self.assertNotIn("https://mail.google.com/", MODULE.EXPECTED_SCOPES)
        self.assertNotIn("https://www.googleapis.com/auth/calendar", MODULE.EXPECTED_SCOPES)

    def test_mime_builds_draft_message(self):
        args = Namespace(
            to="dest@example.com",
            subject="Test",
            body="Bonjour",
            body_file=None,
            cc=None,
            bcc=None,
            html=False,
        )
        encoded = MODULE._mime(args)
        self.assertIsInstance(encoded, str)
        self.assertNotIn("Bonjour", encoded)

    def test_delete_requires_confirmation(self):
        with self.assertRaises(SystemExit):
            MODULE.draft_delete(Namespace(confirm_delete=False, draft_id="x"))
        with self.assertRaises(SystemExit):
            MODULE.calendar_delete(Namespace(confirm_delete=False, event_id="x", calendar="primary"))


if __name__ == "__main__":
    unittest.main()
