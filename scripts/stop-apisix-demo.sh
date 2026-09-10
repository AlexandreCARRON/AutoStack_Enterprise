#!/usr/bin/env bash

# Arrête uniquement le projet Compose de démonstration APISIX.
# Par défaut les volumes sont conservés ; leur suppression exige --volumes puis
# une confirmation explicite pour protéger les routes et journaux locaux.

set -Eeuo pipefail

# Les chemins et le nom de projet correspondent strictement au script de démarrage.
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly DEMO_DIR="${REPO_DIR}/services/APISIX/APISIX_demo_v3.18.0"
readonly ENV_FILE="${DEMO_DIR}/.env"
readonly COMPOSE_FILE="${DEMO_DIR}/docker-compose.yml"

# Sans le fichier privé, le script refuse de deviner quelle instance doit être arrêtée.
[[ -f "$ENV_FILE" ]] || {
  printf "Erreur : %s absent ; aucune instance locale de la démo n’est identifiable.\n" "$ENV_FILE" >&2
  exit 1
}

# Construit une commande stable pour ne jamais cibler un autre projet Compose.
compose=(
  docker compose
  --project-name autostack-apisix-demo
  --project-directory "$REPO_DIR"
  --env-file "$ENV_FILE"
  -f "$COMPOSE_FILE"
)

if [[ "${1:-}" == "--volumes" ]]; then
  # Cette branche détruit les données nommées et impose donc un second consentement.
  read -r -p 'Supprimer aussi les routes APISIX, les index Elasticsearch et tous les volumes de la démo ? [y/N] ' answer
  [[ "$answer" =~ ^[YyOo]$ ]] || {
    printf 'Suppression des volumes annulée.\n'
    exit 0
  }
  "${compose[@]}" down --volumes --remove-orphans
elif (( $# == 0 )); then
  # L'arrêt standard est réversible : les volumes pourront être remontés ultérieurement.
  "${compose[@]}" down --remove-orphans
else
  printf 'Usage : %s [--volumes]\n' "$0" >&2
  exit 2
fi
