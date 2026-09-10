---
id: autostack.tests.readme
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["tests/test-generator.sh", "tests/test_validate_repository.py", "tests/test_validate_roi_pilot.py"]
---

# Tests

Ce dossier contient uniquement les validations génériques du dépôt. Les tests propres à un service sont rangés dans le dossier `tests/` de ce service.

- [`test-generator.sh`](test-generator.sh) vérifie les cas principaux du générateur Docker Compose ;
- [`test_validate_repository.py`](test_validate_repository.py) vérifie le contrat documentaire, les variantes par défaut et les garde-fous du dépôt ;
- [`test_validate_roi_pilot.py`](test_validate_roi_pilot.py) vérifie le contrat du pilote ROI et ses garde-fous pour un dépôt public.

Les tests APISIX sont documentés dans [`services/APISIX/tests/`](../services/APISIX/tests/README.md).
