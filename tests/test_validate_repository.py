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


if __name__ == "__main__":
    unittest.main()
