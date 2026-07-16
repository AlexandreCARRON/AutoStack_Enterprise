#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GENERATOR="${REPO_DIR}/generate-docker-compose.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

if COMPOSE_OUTPUT="${tmp_dir}/empty.yml" ENV_OUTPUT="${tmp_dir}/empty.env" "$GENERATOR" >/dev/null 2>&1; then
  echo "Le générateur devrait refuser une sélection vide." >&2
  exit 1
fi

if COMPOSE_OUTPUT="${tmp_dir}/unknown.yml" ENV_OUTPUT="${tmp_dir}/unknown.env" "$GENERATOR" ServiceInconnu >/dev/null 2>&1; then
  echo "Le générateur devrait refuser un service inconnu." >&2
  exit 1
fi

compose_file="${tmp_dir}/docker-compose.yml"
env_file="${tmp_dir}/.env"

COMPOSE_OUTPUT="$compose_file" ENV_OUTPUT="$env_file" \
  "$GENERATOR" Nginx-Proxy-Manager Odoo >/dev/null

grep -q '^services:$' "$compose_file"
grep -q '^  nginx-proxy-manager:' "$compose_file"
grep -q '^  postgres:' "$compose_file"
grep -q '^PORT_NGINX_PROXY_MANAGER=' "$env_file"
grep -q '^POSTGRES_PASSWORD_ODOO=CHANGE_ME$' "$env_file"

permissions="$(stat -c '%a' "$env_file" 2>/dev/null || stat -f '%Lp' "$env_file")"
[[ "$permissions" == "600" ]]

if COMPOSE_OUTPUT="$compose_file" ENV_OUTPUT="$env_file" \
  "$GENERATOR" Nginx-Proxy-Manager Odoo >/dev/null 2>&1; then
  echo "Le générateur devrait protéger un fichier Compose existant." >&2
  exit 1
fi

FORCE=1 COMPOSE_OUTPUT="$compose_file" ENV_OUTPUT="$env_file" \
  "$GENERATOR" Nginx-Proxy-Manager Odoo >/dev/null

host_env="${tmp_dir}/host.env"
cp "${REPO_DIR}/.env.example" "$host_env"
COMPOSE_OUTPUT="${tmp_dir}/n8n.yml" ENV_OUTPUT="$host_env" \
  "$GENERATOR" N8N >/dev/null
grep -q '^NEW_USER=autostack$' "$host_env"
grep -q '^POSTGRES_NON_ROOT_PASSWORD=CHANGE_ME$' "$host_env"

COMPOSE_OUTPUT="${tmp_dir}/nextcloud.yml" ENV_OUTPUT="${tmp_dir}/nextcloud.env" \
  "$GENERATOR" Nginx-Proxy-Manager Nextcloud-Aio-Mastercontainer >/dev/null
grep -q '^  nextcloud-aio-mastercontainer:' "${tmp_dir}/nextcloud.yml"
grep -q '^volumes:$' "${tmp_dir}/nextcloud.yml"
grep -q '^  nextcloud_aio_mastercontainer:' "${tmp_dir}/nextcloud.yml"

echo "Tests du générateur : OK"
