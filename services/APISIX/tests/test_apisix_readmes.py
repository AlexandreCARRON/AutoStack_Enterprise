import unittest
from pathlib import Path


APISIX_ROOT = Path(__file__).resolve().parents[1]


class ApisixReadmeTests(unittest.TestCase):
    def test_every_source_directory_has_a_readme(self) -> None:
        source_directories = set()
        for path in APISIX_ROOT.rglob("*"):
            if not path.is_file():
                continue
            relative_parts = path.relative_to(APISIX_ROOT).parts
            if "runtime" in relative_parts and any(part in {"certs", "generated"} for part in relative_parts):
                continue
            directory = path.parent
            while directory == APISIX_ROOT or APISIX_ROOT in directory.parents:
                source_directories.add(directory)
                if directory == APISIX_ROOT:
                    break
                directory = directory.parent

        missing = [
            str(directory.relative_to(APISIX_ROOT))
            for directory in sorted(source_directories)
            if not (directory / "README.md").is_file()
        ]
        self.assertEqual(missing, [], f"README.md manquant dans : {', '.join(missing)}")


if __name__ == "__main__":
    unittest.main()
