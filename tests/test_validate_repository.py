#!/usr/bin/env python3
"""Tests for the repository contract validator."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = REPO_ROOT / "scripts" / "validate_repository.py"
SPEC = importlib.util.spec_from_file_location("validate_repository", VALIDATOR_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class RepositoryValidatorTests(unittest.TestCase):
    def test_repository_contract_is_valid(self) -> None:
        self.assertEqual(VALIDATOR.main(), 0)

    def test_missing_default_variant_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            variant = root / "services" / "Example" / "Example_v1"
            variant.mkdir(parents=True)
            (variant / "docker-compose.yml").write_text("services: {}\n", encoding="utf-8")
            (variant / ".env.example").write_text("EXAMPLE=CHANGE_ME\n", encoding="utf-8")
            (variant.parent / "default-version").write_text("Example_v2\n", encoding="utf-8")

            errors = VALIDATOR.validate_default_versions(root)

        self.assertTrue(any("variante introuvable" in error for error in errors))

    def test_required_decision_source_is_enforced(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "decision.md"
            path.write_text(
                "---\n"
                "id: decision.test\n"
                "kind: decision\n"
                "status: active\n"
                "last_reviewed: 2026-08-03\n"
                "sensitivity: public\n"
                "sources: []\n"
                "---\n",
                encoding="utf-8",
            )

            _, errors = VALIDATOR.validate_metadata(path)

        self.assertTrue(any("source est obligatoire" in error for error in errors))

    def test_local_link_cannot_escape_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "README.md"
            path.write_text("[hors dépôt](../secret.txt)\n", encoding="utf-8")

            errors = VALIDATOR.validate_local_links(path, root)

        self.assertTrue(any("lien hors dépôt" in error for error in errors))

    def test_service_script_outside_scripts_directory_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            service = root / "services" / "Example"
            service.mkdir(parents=True)
            (root / "volumes").mkdir()
            (root / "App").mkdir()
            (service / "maintenance.sh").write_text("#!/bin/sh\n", encoding="utf-8")

            errors = VALIDATOR.validate_script_layout(root)

        self.assertTrue(any("maintenance.sh" in error for error in errors))

    def test_nested_service_python_file_outside_scripts_or_tests_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            variant = root / "services" / "Example" / "Example_v1" / "runtime"
            variant.mkdir(parents=True)
            (variant / "worker.py").write_text("print('demo')\n", encoding="utf-8")

            errors = VALIDATOR.validate_script_layout(root)

        self.assertTrue(any("worker.py" in error for error in errors))

    def test_python_test_in_service_tests_directory_is_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / "services" / "Example" / "tests"
            tests.mkdir(parents=True)
            (tests / "test_worker.py").write_text("print('test')\n", encoding="utf-8")

            errors = VALIDATOR.validate_script_layout(root)

        self.assertEqual(errors, [])

    def test_non_autonomous_service_compose_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            variant = root / "services" / "Example" / "Example_v1"
            variant.mkdir(parents=True)
            (variant / "docker-compose.yml").write_text(
                "example:\n"
                "  image: example:1\n"
                "  volumes:\n"
                "    - ./volumes/example:/data\n",
                encoding="utf-8",
            )

            errors = VALIDATOR.validate_service_autonomy(root)

        self.assertTrue(any("section Compose services absente" in error for error in errors))
        self.assertTrue(any("chemin dépendant" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
