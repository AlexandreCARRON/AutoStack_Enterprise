---
id: autostack.apisix.3-18-0.configuration
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_v3.18.0/apisix/config.yaml"]
---

# Configuration APISIX

[`config.yaml`](config.yaml) est monté en lecture seule dans `/usr/local/apisix/conf/config.yaml`.

Il configure APISIX en mode traditionnel avec etcd, active le Dashboard embarqué et exige la variable `APISIX_ADMIN_KEY` pour l'Admin API. La publication de cette API reste liée à `127.0.0.1` par défaut dans le fichier Compose parent.

Ne placez aucun secret directement dans ce dossier : les valeurs locales appartiennent au fichier `.env`, ignoré par Git.
