---
id: autostack.scripts.readme
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["scripts/validate_repository.py", "scripts/validate_roi_pilot.py"]
---

# Scripts

Ce dossier contient les contrôles locaux propres à AutoStack Enterprise.

- [`validate_repository.py`](validate_repository.py) valide les métadonnées et liens de la documentation maintenue, les variantes par défaut et l'hygiène élémentaire des fichiers sensibles ;
- [`validate_roi_pilot.py`](validate_roi_pilot.py) valide la sélection des KPI et les observations publiques du pilote ROI avec la bibliothèque standard Python.

Ces scripts ne modifient aucun fichier. Le validateur ROI ne calcule pas un ROI et refuse notamment les mesures en euros lorsque le pilote est déclaré `public-operational-only`.
