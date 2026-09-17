---
id: autostack.apisix.demo-3-18-0
kind: guide
status: active
last_reviewed: 2026-09-17
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/docker-compose.yml", "services/APISIX/DEMO.md"]
---

# APISIX 3.18.0 — environnement de démonstration

Cette variante ajoute à APISIX un fournisseur d'identité Keycloak avec PostgreSQL, une API interne fictive, un backend partenaire HTTPS/mTLS, trois clients réseau simulés et une chaîne Logstash, Elasticsearch et Kibana.

Pour la démonstration, Keycloak et Kibana utilisent `admin` / `42424242424242424242424242424242`. Le Dashboard APISIX utilise ce même secret comme clé Admin, sans nom d'utilisateur.

## Contenu

- [`docker-compose.yml`](docker-compose.yml) définit la topologie complète ;
- [`.env.example`](.env.example) documente les paramètres locaux ;
- [`apisix/`](apisix/README.md) configure la gateway ;
- [`keycloak/`](keycloak/README.md) importe le realm, les clients OIDC et l'utilisateur fictif ;
- [`../scripts/`](../scripts/README.md) contient le bootstrap, les API fictives, les clients et les lanceurs ;
- [`logstash/`](logstash/README.md) configure l'ingestion des journaux ;
- [`runtime/`](runtime/README.md) reçoit les secrets générés et fichiers temporaires.

Suivez le [guide de démonstration complet](../DEMO.md) pour préparer Debian 12, démarrer la stack et exécuter les scénarios.
