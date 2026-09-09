---
id: autostack.scripts.readme
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["scripts/validate_repository.py", "scripts/validate_roi_pilot.py", "scripts/generate-apisix-demo-config.py", "https://docs.docker.com/reference/cli/dockerd/#insecure-registries"]
---

# Scripts

Ce dossier contient les contrôles locaux propres à AutoStack Enterprise.

- [`validate_repository.py`](validate_repository.py) valide les métadonnées et liens de la documentation maintenue, les variantes par défaut et l'hygiène élémentaire des fichiers sensibles ;
- [`validate_roi_pilot.py`](validate_roi_pilot.py) valide la sélection des KPI et les observations publiques du pilote ROI avec la bibliothèque standard Python ;
- [`generate-apisix-demo-config.py`](generate-apisix-demo-config.py) lit le classeur de démonstration avec la bibliothèque standard et génère les objets APISIX attendus ;
- [`start-apisix-demo.sh`](start-apisix-demo.sh) prépare les secrets et certificats locaux, démarre la chaîne APISIX/ELK et applique la configuration ;
- [`run-apisix-demo-scenarios.sh`](run-apisix-demo-scenarios.sh) vérifie les parcours partenaire, SI interne, mTLS et observabilité ;
- [`stop-apisix-demo.sh`](stop-apisix-demo.sh) arrête la démonstration et ne supprime ses volumes qu'après une option et une confirmation explicites ;
- [`idempotent/configure-docker-insecure-registries.sh`](idempotent/configure-docker-insecure-registries.sh) guide l'ouverture temporaire d'exceptions TLS Docker sur Debian 12, leur retrait après le pull et le redémarrage de la stack Compose, avec sauvegarde et validation de `daemon.json`.

Les validateurs ne modifient aucun fichier. Le validateur ROI ne calcule pas un ROI et refuse notamment les mesures en euros lorsque le pilote est déclaré `public-operational-only`. Le script de configuration Docker modifie `/etc/docker/daemon.json` uniquement après confirmation explicite.
