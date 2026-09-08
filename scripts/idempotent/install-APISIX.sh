#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly VARIANT_DIR="${REPO_DIR}/services/APISIX/APISIX_v3.18.0"
readonly ENV_FILE="${APISIX_ENV_FILE:-${VARIANT_DIR}/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  cp -- "${VARIANT_DIR}/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  printf 'Configuration créée : %s\n' "$ENV_FILE"
  printf 'Remplacez APISIX_ADMIN_KEY, puis relancez ce script.\n' >&2
  exit 1
fi

if grep -Eq '^[A-Z0-9_]+=.*CHANGE_ME' "$ENV_FILE"; then
  printf 'Erreur : remplacez toutes les valeurs CHANGE_ME dans %s.\n' "$ENV_FILE" >&2
  exit 1
fi

docker compose \
  --project-directory "$REPO_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  config --quiet

docker compose \
  --project-directory "$REPO_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  pull

docker compose \
  --project-directory "$REPO_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  up -d --wait

docker compose \
  --project-directory "$REPO_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  ps
