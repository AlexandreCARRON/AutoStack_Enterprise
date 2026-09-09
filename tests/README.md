---
id: autostack.tests.readme
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["tests/test-generator.sh", "tests/test_apisix_readmes.py", "tests/test_generate_apisix_demo_config.py", "tests/test_validate_repository.py", "tests/test_validate_roi_pilot.py"]
---

# Tests

Ce dossier contient les validations exécutables du dépôt.

- [`test-generator.sh`](test-generator.sh) vérifie les cas principaux du générateur Docker Compose ;
- [`test_apisix_readmes.py`](test_apisix_readmes.py) garantit que chaque dossier source du projet APISIX possède un `README.md` ;
- [`test_generate_apisix_demo_config.py`](test_generate_apisix_demo_config.py) contrôle les objets APISIX produits depuis le classeur de démonstration ;
- [`test_validate_repository.py`](test_validate_repository.py) vérifie le contrat documentaire, les variantes par défaut et les garde-fous du dépôt ;
- [`test_validate_roi_pilot.py`](test_validate_roi_pilot.py) vérifie le contrat du pilote ROI et ses garde-fous pour un dépôt public.
