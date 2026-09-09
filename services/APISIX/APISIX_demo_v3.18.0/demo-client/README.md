---
id: autostack.apisix.demo-3-18-0.client
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/demo-client/client.py"]
---

# Clients de démonstration

[`client.py`](client.py) est lancé dans des conteneurs éphémères pour émettre les appels depuis deux réseaux isolés :

- `partner-client` simule le partenaire qui consomme l'API interne via APISIX ;
- `si-client` simule le SI interne qui appelle le backend externe via APISIX.

Le script vérifie le code HTTP attendu et affiche le corps JSON pour que `scripts/run-apisix-demo-scenarios.sh` valide le résultat.
