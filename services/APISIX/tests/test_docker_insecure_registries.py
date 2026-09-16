#!/usr/bin/env python3
"""Tests for the Debian Docker insecure-registry helper."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SERVICE_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = SERVICE_ROOT / "scripts" / "configure-docker-insecure-registries.sh"
START_SCRIPT = SERVICE_ROOT / "scripts" / "start-apisix-demo.sh"


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

    def install_fake_command(self, name: str) -> None:
        binary = self.directory / "bin" / name
        binary.parent.mkdir(exist_ok=True)
        binary.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        binary.chmod(0o755)

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

    def test_list_reports_existing_registries_without_modifying_config(self) -> None:
        expected = {
            "insecure-registries": ["registry.example.net", "cdn01.quay.io"],
            "log-driver": "local",
        }
        self.config.write_text(json.dumps(expected), encoding="utf-8")

        result = subprocess.run(
            [
                str(SCRIPT),
                "--list",
                "--config",
                str(self.config),
            ],
            check=False,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["registry.example.net", "cdn01.quay.io"],
        )
        self.assertEqual(json.loads(self.config.read_text(encoding="utf-8")), expected)

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

    def test_demo_pull_fallback_restores_only_its_temporary_exceptions(self) -> None:
        original_config = {
            "insecure-registries": ["registry.example.net"],
            "log-driver": "local",
        }
        self.config.write_text(json.dumps(original_config), encoding="utf-8")
        counter = self.directory / "pull-attempts"
        counter.write_text("0\n", encoding="utf-8")
        self.install_fake_command("dockerd")
        self.install_fake_command("systemctl")
        environment = {
            **self.environment,
            "AUTOSTACK_DOCKER_CONFIG_FILE": str(self.config),
            "AUTOSTACK_TEST_PULL_COUNTER": str(counter),
            "PATH": f"{self.directory / 'bin'}:{self.environment['PATH']}",
        }

        result = subprocess.run(
            [
                "bash",
                "-c",
                r'''
start_script="$1"
set --
source "$start_script"
is_debian_12() { return 0; }
run_as_root() {
  if [[ "$1" == "$TLS_HELPER" ]]; then
    local helper="$1"
    shift
    "$helper" --no-restart "$@"
  else
    "$@"
  fi
}
wait_for_docker() { return 0; }
compose() {
  local attempts
  attempts="$(cat "$AUTOSTACK_TEST_PULL_COUNTER")"
  attempts=$((attempts + 1))
  printf '%s\n' "$attempts" > "$AUTOSTACK_TEST_PULL_COUNTER"
  if (( attempts == 1 )); then
    printf '%s\n' 'Get "https://cdn01.quay.io/blob": tls: failed to verify certificate: x509: certificate signed by unknown authority' >&2
    return 1
  fi
  return 0
}
pull_images_with_tls_fallback
''',
                "_",
                str(START_SCRIPT),
                str(counter),
            ],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            counter.read_text(encoding="utf-8").strip(),
            "2",
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )
        self.assertIn("Validation TLS Docker réactivée", result.stdout)
        self.assertEqual(
            json.loads(self.config.read_text(encoding="utf-8")),
            original_config,
        )


if __name__ == "__main__":
    unittest.main()
