---
id: autostack.scripts.readme
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["scripts/validate_roi_pilot.py"]
---

# Scripts

Ce dossier contient les contrôles locaux propres à AutoStack Enterprise.

- [`validate_roi_pilot.py`](validate_roi_pilot.py) valide la sélection des KPI et les observations publiques du pilote ROI avec la bibliothèque standard Python.

Le script ne calcule pas un ROI et ne modifie aucun fichier. Il refuse notamment les mesures en euros lorsque le pilote est déclaré `public-operational-only`.
