---
id: autostack.apisix.demo-3-18-0.api
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/demo-api/server.py", "services/APISIX/APISIX_demo_v3.18.0/demo-api/Dockerfile"]
---

# API fictive de démonstration

Le même code Python est instancié dans deux rôles :

- `internal-api` expose une API de commandes HTTP uniquement sur le réseau interne ;
- `partner-api` expose un backend partenaire HTTPS qui exige un certificat client et une clé applicative.

[`server.py`](server.py) utilise uniquement la bibliothèque standard Python. Le [`Dockerfile`](Dockerfile) construit une image sans dépendance applicative supplémentaire.
