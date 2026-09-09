---
id: autostack.apisix.demo-3-18-0.logstash-pipeline
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/logstash/pipeline/logstash.conf"]
---

# Pipeline Logstash

[`logstash.conf`](logstash.conf) écoute les événements JSON d'APISIX sur le port interne `8080`, enrichit les événements avec le dataset `apisix.access` et les indexe dans `apisix-demo-YYYY.MM.dd`.

Le port Logstash n'est pas publié sur l'hôte. Seuls les conteneurs reliés au réseau d'observabilité peuvent l'utiliser.
