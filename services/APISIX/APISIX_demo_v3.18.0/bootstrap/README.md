---
id: autostack.apisix.demo-3-18-0.bootstrap
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/bootstrap/bootstrap.py"]
---

# Bootstrap de la démonstration

[`bootstrap.py`](bootstrap.py) applique de façon idempotente la configuration de la démonstration.

Le script attend APISIX, Logstash et Kibana, puis crée les upstreams, routes, consommateurs et credentials. Il insère le certificat client dans l'upstream mTLS et prépare la vue de données Kibana `apisix-demo-*`.

Il est exécuté par le service Compose `demo-configurator` via `scripts/start-apisix-demo.sh` et ne doit pas être lancé directement sur l'hôte.
