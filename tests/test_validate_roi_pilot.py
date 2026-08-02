#!/usr/bin/env python3
"""Test the AutoStack ROI pilot validator with repository and invalid fixtures."""

from __future__ import annotations

import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = REPO_ROOT / "scripts" / "validate_roi_pilot.py"
SPEC = importlib.util.spec_from_file_location("validate_roi_pilot", VALIDATOR_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class RoiPilotValidatorTests(unittest.TestCase):
    # Vérifie que les fichiers réellement versionnés respectent leur propre contrat.
    def test_repository_measurement_is_valid(self) -> None:
        result = VALIDATOR.main([
            str(REPO_ROOT / "measurement" / "KPI-SELECTION.yml"),
            "--observations",
            str(REPO_ROOT / "measurement" / "OBSERVATIONS.jsonl"),
        ])
        self.assertEqual(result, 0)

    # Vérifie qu'une observation financière ne peut pas être publiée par contournement.
    def test_public_financial_observation_is_rejected(self) -> None:
        selection = VALIDATOR.load_selection(REPO_ROOT / "measurement" / "KPI-SELECTION.yml")
        selection["selected_kpis"][0]["unit"] = "EUR"
        observation = json.loads(
            (REPO_ROOT / "measurement" / "OBSERVATIONS.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()[0]
        )
        observation["unit"] = "EUR"

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            selection_path = root / "selection.json"
            observation_path = root / "observations.jsonl"
            selection_path.write_text(json.dumps(selection), encoding="utf-8")
            observation_path.write_text(json.dumps(observation) + "\n", encoding="utf-8")
            output = io.StringIO()
            with redirect_stdout(output):
                result = VALIDATOR.main([
                    str(selection_path),
                    "--observations",
                    str(observation_path),
                ])
        self.assertEqual(result, 1)
        self.assertIn("mesure financière interdite", output.getvalue())


if __name__ == "__main__":
    unittest.main()
