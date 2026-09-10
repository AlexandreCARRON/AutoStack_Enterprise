---
id: autostack.scripts.readme
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["scripts/generate-docker-compose.sh", "scripts/script-conf-server-D12.sh", "scripts/validate_repository.py", "scripts/validate_roi_pilot.py"]
---

# Scripts

Ce dossier contient uniquement les scripts génériques qui agissent sur le dépôt ou sur l'hôte AutoStack. Les scripts propres à une application ou à un service sont rangés dans le dossier `scripts/` de sa racine.

- [`generate-docker-compose.sh`](generate-docker-compose.sh) assemble les variantes de services sélectionnées et leur fichier d'environnement ;
- [`script-conf-server-D12.sh`](script-conf-server-D12.sh) prépare un hôte Debian 12 pour AutoStack ;
- [`validate_repository.py`](validate_repository.py) valide les métadonnées et liens de la documentation maintenue, les variantes par défaut, l'hygiène élémentaire des fichiers sensibles, le rangement des scripts et l'autonomie Compose des services ;
- [`validate_roi_pilot.py`](validate_roi_pilot.py) valide la sélection des KPI et les observations publiques du pilote ROI avec la bibliothèque standard Python.

Les validateurs ne modifient aucun fichier. Le validateur ROI ne calcule pas un ROI et refuse notamment les mesures en euros lorsque le pilote est déclaré `public-operational-only`.

Les outils APISIX sont documentés dans [`services/APISIX/scripts/`](../services/APISIX/scripts/README.md).
