#!/usr/bin/env python3
"""Contrats déterministes de l'intégration Keycloak/OIDC de la démo."""

from __future__ import annotations

import importlib.util
import json
import os
import unittest
from pathlib import Path
from unittest import mock


SERVICE_ROOT = Path(__file__).resolve().parents[1]
REALM_FILE = (
    SERVICE_ROOT
    / "APISIX_demo_v3.18.0"
    / "keycloak"
    / "autostack-realm.json"
)
BOOTSTRAP_FILE = SERVICE_ROOT / "scripts" / "bootstrap.py"
CLIENT_FILE = SERVICE_ROOT / "scripts" / "client.py"
START_SCRIPT = SERVICE_ROOT / "scripts" / "start-apisix-demo.sh"
DEMO_ENV_EXAMPLE = SERVICE_ROOT / "APISIX_demo_v3.18.0" / ".env.example"
APISIX_CONFIG = (
    SERVICE_ROOT / "APISIX_demo_v3.18.0" / "apisix" / "config.yaml"
)


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"module Python introuvable : {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeResponse:
    def __init__(self, payload: object) -> None:
        self.payload = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def read(self) -> bytes:
        return self.payload


class KeycloakDemoTests(unittest.TestCase):
    def test_start_script_is_autonomous_and_restores_tls(self) -> None:
        script = START_SCRIPT.read_text(encoding="utf-8")

        self.assertIn(
            'DEFAULT_APISIX_ADMIN_KEY="42424242424242424242424242424242"',
            script,
        )
        self.assertIn("ASSUME_YES=1", script)
        self.assertIn("pull_images_with_tls_fallback", script)
        self.assertIn("restore_tls_exceptions", script)
        self.assertIn('"${SCRIPT_DIR}/run-apisix-demo-scenarios.sh"', script)

        admin_key = "42424242424242424242424242424242"
        self.assertIn(f"APISIX_ADMIN_KEY={admin_key}", DEMO_ENV_EXAMPLE.read_text())
        self.assertIn(f'key: "{admin_key}"', APISIX_CONFIG.read_text())

    def test_realm_uses_only_environment_backed_secrets(self) -> None:
        realm = json.loads(REALM_FILE.read_text(encoding="utf-8"))
        self.assertEqual(realm["realm"], "autostack")

        clients = {client["clientId"]: client for client in realm["clients"]}
        self.assertEqual(
            clients["autostack-apisix-bff"]["secret"],
            "${KEYCLOAK_APISIX_CLIENT_SECRET}",
        )
        self.assertTrue(clients["autostack-apisix-bff"]["standardFlowEnabled"])
        self.assertTrue(clients["autostack-partner"]["serviceAccountsEnabled"])
        self.assertEqual(
            realm["users"][0]["credentials"][0]["value"],
            "${KEYCLOAK_DEMO_USER_PASSWORD}",
        )

    def test_bootstrap_builds_bearer_and_bff_oidc_modes(self) -> None:
        environment = {
            "APISIX_ADMIN_KEY": "test-admin-key",
            "APISIX_OIDC_SESSION_SECRET": "0123456789abcdef0123456789abcdef",
        }
        with mock.patch.dict(os.environ, environment):
            bootstrap = load_module("autostack_apisix_bootstrap", BOOTSTRAP_FILE)
            bearer = bootstrap.oidc_plugin(bearer_only=True)
            self.assertTrue(bearer["bearer_only"])
            self.assertTrue(bearer["use_jwks"])
            self.assertNotIn("session", bearer)

            bff = bootstrap.oidc_plugin(bearer_only=False)
            self.assertFalse(bff["bearer_only"])
            self.assertTrue(bff["use_pkce"])
            self.assertTrue(bff["session"]["cookie_http_only"])
            self.assertEqual(bff["session"]["cookie_same_site"], "Lax")

    def test_client_credentials_token_is_kept_in_memory(self) -> None:
        environment = {
            "OIDC_TOKEN_URL": "http://keycloak/token",
            "OIDC_CLIENT_ID": "autostack-partner",
            "OIDC_CLIENT_SECRET": "local-test-secret",
        }
        client = load_module("autostack_apisix_client", CLIENT_FILE)
        with (
            mock.patch.dict(os.environ, environment),
            mock.patch.object(
                client.urllib.request,
                "urlopen",
                return_value=FakeResponse({"access_token": "signed-token"}),
            ),
        ):
            self.assertEqual(client.client_credentials_token(), "signed-token")


if __name__ == "__main__":
    unittest.main()
