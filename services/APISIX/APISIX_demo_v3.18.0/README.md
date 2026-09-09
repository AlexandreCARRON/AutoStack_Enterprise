---
id: autostack.apisix.demo-3-18-0
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/docker-compose.yml", "services/APISIX/DEMO.md"]
---

# APISIX 3.18.0 — environnement de démonstration

Cette variante ajoute à APISIX une API interne fictive, un backend partenaire HTTPS/mTLS, deux clients réseau simulés et une chaîne Logstash, Elasticsearch et Kibana.

## Contenu

- [`docker-compose.yml`](docker-compose.yml) définit la topologie complète ;
- [`.env.example`](.env.example) documente les paramètres locaux ;
- [`apisix/`](apisix/README.md) configure la gateway ;
- [`bootstrap/`](bootstrap/README.md) charge les objets APISIX et prépare Kibana ;
- [`demo-api/`](demo-api/README.md) implémente les API fictives ;
- [`demo-client/`](demo-client/README.md) fournit les clients de scénario ;
- [`logstash/`](logstash/README.md) configure l'ingestion des journaux ;
- [`runtime/`](runtime/README.md) reçoit les secrets générés et fichiers temporaires.

Suivez le [guide de démonstration complet](../DEMO.md) pour préparer Debian 12, démarrer la stack et exécuter les scénarios.
