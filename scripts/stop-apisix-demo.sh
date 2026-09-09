#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEMO_DIR="${REPO_DIR}/services/APISIX/APISIX_demo_v3.18.0"
readonly ENV_FILE="${DEMO_DIR}/.env"
readonly COMPOSE_FILE="${DEMO_DIR}/docker-compose.yml"

[[ -f "$ENV_FILE" ]] || {
  printf 'Erreur : %s absent ; aucune instance locale de la démo n’est identifiable.\n' "$ENV_FILE" >&2
  exit 1
}

compose=(
  docker compose
  --project-name autostack-apisix-demo
  --project-directory "$REPO_DIR"
  --env-file "$ENV_FILE"
  -f "$COMPOSE_FILE"
)

if [[ "${1:-}" == "--volumes" ]]; then
  read -r -p 'Supprimer aussi les routes APISIX, les index Elasticsearch et tous les volumes de la démo ? [y/N] ' answer
  [[ "$answer" =~ ^[YyOo]$ ]] || {
    printf 'Suppression des volumes annulée.\n'
    exit 0
  }
  "${compose[@]}" down --volumes --remove-orphans
elif (( $# == 0 )); then
  "${compose[@]}" down --remove-orphans
else
  printf 'Usage : %s [--volumes]\n' "$0" >&2
  exit 2
fi
