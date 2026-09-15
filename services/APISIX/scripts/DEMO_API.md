---
id: autostack.apisix.demo-3-18-0.api
kind: guide
status: active
last_reviewed: 2026-09-15
sensitivity: public
sources: ["services/APISIX/scripts/server.py", "services/APISIX/scripts/Dockerfile.demo-api"]
---

# API fictive de démonstration

Le même code Python est instancié dans deux rôles :

- `internal-api` expose une API de commandes HTTP uniquement sur le réseau interne ;
- `partner-api` expose un backend partenaire HTTPS qui exige un certificat client et une clé applicative.

[`server.py`](server.py) utilise uniquement la bibliothèque standard Python. Le [`Dockerfile.demo-api`](Dockerfile.demo-api) construit une image sans dépendance applicative supplémentaire.

L'API interne indique dans sa réponse si APISIX a transmis un access token et décode l'en-tête `X-Userinfo` lorsqu'il est présent. Elle ne renvoie jamais le jeton lui-même.
