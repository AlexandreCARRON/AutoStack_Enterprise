---
id: autostack.apisix.demo-3-18-0.configuration
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/apisix/config.yaml"]
---

# Configuration APISIX de démonstration

[`config.yaml`](config.yaml) configure APISIX 3.18.0 avec etcd et le Dashboard embarqué.

Les routes, upstreams, consommateurs et plugins ne sont pas codés en dur dans ce fichier. Le composant de [bootstrap](../bootstrap/README.md) les crée via l'Admin API à partir des fichiers JSON générés depuis le classeur.
