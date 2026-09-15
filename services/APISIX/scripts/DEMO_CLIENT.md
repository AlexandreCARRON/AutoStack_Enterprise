---
id: autostack.apisix.demo-3-18-0.client
kind: guide
status: active
last_reviewed: 2026-09-15
sensitivity: public
sources: ["services/APISIX/scripts/client.py"]
---

# Clients de démonstration

[`client.py`](client.py) est lancé dans des conteneurs éphémères pour émettre les appels depuis deux réseaux isolés :

- `partner-client` simule le partenaire qui consomme l'API interne via APISIX ;
- `si-client` simule le SI interne qui appelle le backend externe via APISIX.
- `oidc-partner-client` obtient un access token Keycloak avec `client_credentials`, le conserve en mémoire et appelle la route OIDC d'APISIX.

Le script vérifie le code HTTP attendu et affiche le corps JSON pour que [`run-apisix-demo-scenarios.sh`](run-apisix-demo-scenarios.sh) valide le résultat. L'option `--without-auth` permet de prouver le refus d'une requête anonyme ; `--without-key` reste un alias compatible avec les scénarios historiques.
