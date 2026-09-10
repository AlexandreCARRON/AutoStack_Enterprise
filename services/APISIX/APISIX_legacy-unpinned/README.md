---
id: autostack.apisix.legacy-unpinned
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_legacy-unpinned/docker-compose.yml", "services/APISIX/scripts/install-legacy-poc.sh"]
---

# APISIX historique non épinglé

Cette variante conserve le POC historique avec des images flottantes, des adresses IP statiques et un ancien Dashboard séparé. Elle est maintenue uniquement pour référence et ne doit pas servir de cible de déploiement.

## Contenu

- [`docker-compose.yml`](docker-compose.yml) contient l'ancienne topologie ;
- [`../scripts/install-legacy-poc.sh`](../scripts/install-legacy-poc.sh) contient l'ancien installateur POC ;
- [`apisix/`](apisix/README.md) contient l'ancienne configuration APISIX ;
- [`dashboard/`](dashboard/README.md) contient la configuration de l'ancien Dashboard.

Utilisez la [variante APISIX 3.18.0](../APISIX_v3.18.0/README.md) pour tout nouveau déploiement.
