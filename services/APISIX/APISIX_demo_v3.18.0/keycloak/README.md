---
id: autostack.apisix.demo-3-18-0.keycloak
kind: guide
status: active
last_reviewed: 2026-09-15
sensitivity: public
sources: ["https://www.keycloak.org/server/containers", "https://www.keycloak.org/server/importExport", "https://apisix.apache.org/docs/apisix/plugins/openid-connect/"]
---

# Realm Keycloak de démonstration

[`autostack-realm.json`](autostack-realm.json) initialise le realm `autostack`, le client confidentiel `autostack-apisix-bff`, le client machine-à-machine `autostack-partner` et l'utilisateur fictif `architecte-demo`.

Le fichier ne contient aucun secret utilisable. Keycloak remplace ses marqueurs `${VARIABLE}` par les valeurs du `.env` local au premier démarrage. L'import de démarrage ignore un realm qui existe déjà ; après une modification structurelle de ce fichier, réinitialisez volontairement le volume Keycloak avec `./scripts/stop-apisix-demo.sh --volumes`, puis redémarrez la démo.

Cette configuration utilise `start-dev`, HTTP et `sslRequired=none` uniquement pour la VM de démonstration. Un déploiement réel exige le mode production, HTTPS, une séparation de l'administration et une gestion externe des secrets.
