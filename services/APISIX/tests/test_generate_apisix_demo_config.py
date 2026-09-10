import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SERVICE_ROOT = Path(__file__).resolve().parents[1]
GENERATOR = SERVICE_ROOT / "scripts" / "generate-apisix-demo-config.py"
WORKBOOK = (
    SERVICE_ROOT
    / "APISIX_v3.18.0"
    / "fichiers"
    / "AutoStack_Demo_APISIX.xlsx"
)


class GenerateApisixDemoConfigTests(unittest.TestCase):
    def test_generates_expected_apisix_objects(self) -> None:
        with tempfile.TemporaryDirectory() as output:
            result = subprocess.run(
                [sys.executable, str(GENERATOR), str(WORKBOOK), output],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            generated = Path(output)
            expected = {
                "consumer.json",
                "manifest.json",
                "plugins.json",
                "route.json",
                "upstream.json",
            }
            self.assertEqual({path.name for path in generated.glob("*.json")}, expected)

            upstream = json.loads((generated / "upstream.json").read_text(encoding="utf-8"))
            self.assertEqual(upstream["scheme"], "https")
            self.assertEqual(upstream["nodes"], {"backend-partenaire-a.toto.local:8443": 1})
            self.assertEqual(upstream["retries"], 3)

            route = json.loads((generated / "route.json").read_text(encoding="utf-8"))
            self.assertEqual(route["uri"], "/partenaire-a/*")
            self.assertEqual(route["methods"], ["GET", "POST"])
            self.assertIn("key-auth", route["plugins"])
            self.assertIn("http-logger", route["plugins"])
            self.assertIn("proxy-rewrite", route["plugins"])

            consumer = json.loads((generated / "consumer.json").read_text(encoding="utf-8"))
            self.assertEqual(consumer["username"], "partenaire_A")
            self.assertEqual(
                consumer["credential"]["plugins"]["key-auth"]["key"],
                "${DEMO_PARTNER_API_KEY}",
            )


if __name__ == "__main__":
    unittest.main()
