---
id: autostack.apisix.3-18-0
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_v3.18.0/docker-compose.yml", "services/APISIX/APISIX_v3.18.0/apisix/config.yaml"]
---

# APISIX 3.18.0

Cette variante est la version APISIX par défaut du dépôt. Elle déploie APISIX 3.18.0, son Dashboard embarqué et etcd 3.5.18.

## Contenu

- [`docker-compose.yml`](docker-compose.yml) définit APISIX, etcd, les volumes et les réseaux ;
- [`.env.example`](.env.example) documente les images, clés et ports configurables ;
- [`apisix/`](apisix/README.md) contient la configuration montée dans le conteneur ;
- [`fichiers/`](fichiers/README.md) contient le classeur d'entrée de la démonstration.

Le démarrage et les règles de sécurité sont documentés dans le [guide APISIX](../README.md). La chaîne de démonstration complète utilise une variante distincte décrite dans le [guide de démonstration](../DEMO.md).
