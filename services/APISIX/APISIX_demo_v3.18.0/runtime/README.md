---
id: autostack.apisix.demo-3-18-0.runtime
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["services/APISIX/APISIX_demo_v3.18.0/runtime/.gitignore", "scripts/start-apisix-demo.sh"]
---

# Fichiers d'exécution locaux

Ce dossier reçoit les artefacts créés par `scripts/start-apisix-demo.sh` :

- `certs/` contient l'autorité et les certificats mTLS de démonstration ;
- `generated/` contient les objets JSON produits depuis le classeur.

Son contenu est ignoré par Git, à l'exception de ce README et de `.gitignore`. Ne publiez jamais les clés privées ou les secrets générés localement.
