---
id: autostack.apisix.demo-3-18-0.logstash
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/logstash/pipeline/logstash.conf"]
---

# Logstash de démonstration

Ce dossier contient la configuration d'ingestion des journaux APISIX.

Le sous-dossier [`pipeline/`](pipeline/README.md) définit une entrée HTTP consommée par le plugin APISIX `http-logger` et une sortie vers Elasticsearch.
