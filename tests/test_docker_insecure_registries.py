#!/usr/bin/env python3
"""Tests for the Debian Docker insecure-registry helper."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts/idempotent/configure-docker-insecure-registries.sh"


class DockerInsecureRegistriesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.directory = Path(self.temporary_directory.name)
        self.config = self.directory / "daemon.json"
        self.os_release = self.directory / "os-release"
        self.os_release.write_text('ID=debian\nVERSION_ID="12"\n', encoding="utf-8")
        self.environment = {
            **os.environ,
            "AUTOSTACK_OS_RELEASE_FILE": str(self.os_release),
        }

    def run_script(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                str(SCRIPT),
                "--add-only",
                "--yes",
                "--no-restart",
                "--config",
                str(self.config),
                *arguments,
            ],
            check=False,
            capture_output=True,
            text=True,
            env=self.environment,
        )

    def test_defaults_are_idempotent_and_preserve_existing_configuration(self) -> None:
        self.config.write_text('{"log-driver": "local"}\n', encoding="utf-8")

        first = self.run_script()
        second = self.run_script()

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("déjà à jour", second.stdout)
        self.assertEqual(
            json.loads(self.config.read_text(encoding="utf-8")),
            {
                "insecure-registries": ["quay.io", "cdn01.quay.io"],
                "log-driver": "local",
            },
        )

    def test_remove_restores_secure_registry_configuration(self) -> None:
        self.config.write_text(
            json.dumps(
                {
                    "insecure-registries": ["quay.io", "cdn01.quay.io"],
                    "log-driver": "local",
                }
            ),
            encoding="utf-8",
        )

        result = self.run_script("--remove")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.config.read_text(encoding="utf-8")),
            {"log-driver": "local"},
        )

    def test_rejects_invalid_registry(self) -> None:
        result = self.run_script("quay.io;example.net")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("registre invalide", result.stderr)

    def test_guided_workflow_removes_temporary_exceptions(self) -> None:
        self.config.write_text('{"log-driver": "local"}\n', encoding="utf-8")

        result = subprocess.run(
            [
                str(SCRIPT),
                "--no-restart",
                "--config",
                str(self.config),
            ],
            input="\n\n\n\n\n\n\nn\n",
            check=False,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("TLS est réactivé", result.stdout)
        self.assertEqual(
            json.loads(self.config.read_text(encoding="utf-8")),
            {"log-driver": "local"},
        )


if __name__ == "__main__":
    unittest.main()
