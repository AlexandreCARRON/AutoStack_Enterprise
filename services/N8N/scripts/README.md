---
id: autostack.n8n.scripts
kind: guide
status: active
last_reviewed: 2026-09-10
sensitivity: public
sources: ["services/N8N/N8N_v2.30.5/docker-compose.yml", "services/N8N/N8N_legacy-unpinned/docker-compose.yml"]
---

# Scripts n8n

[`init-data.sh`](init-data.sh) initialise l'utilisateur PostgreSQL non privilégié. La variante n8n maintenue et la variante historique utilisent toutes deux ce fichier en lecture seule dans le conteneur PostgreSQL.
