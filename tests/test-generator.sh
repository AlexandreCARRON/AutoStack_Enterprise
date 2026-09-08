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

if COMPOSE_OUTPUT="${tmp_dir}/traversal.yml" ENV_OUTPUT="${tmp_dir}/traversal.env" \
  "$GENERATOR" Odoo/../Odoo_v19 >/dev/null 2>&1; then
  echo "Le générateur devrait refuser une traversée de chemin." >&2
  exit 1
fi

compose_file="${tmp_dir}/docker-compose.yml"
env_file="${tmp_dir}/.env"

COMPOSE_OUTPUT="$compose_file" ENV_OUTPUT="$env_file" \
  "$GENERATOR" Nginx-Proxy-Manager Odoo >/dev/null

grep -q '^services:$' "$compose_file"
grep -q '^  nginx-proxy-manager:' "$compose_file"
grep -q '^  postgres:' "$compose_file"
grep -q '^configs:$' "$compose_file"
grep -q '^PORT_NGINX_PROXY_MANAGER=' "$env_file"
grep -q '^ODOO_IMAGE=odoo:19.0-20260630$' "$env_file"
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

if COMPOSE_OUTPUT="${tmp_dir}/duplicate.yml" ENV_OUTPUT="${tmp_dir}/duplicate.env" \
  "$GENERATOR" Odoo Odoo/Odoo_v19 >/dev/null 2>&1; then
  echo "Le générateur devrait détecter une variante sélectionnée via deux alias." >&2
  exit 1
fi

COMPOSE_OUTPUT="${tmp_dir}/odoo17.yml" ENV_OUTPUT="${tmp_dir}/odoo17.env" \
  "$GENERATOR" Odoo/Odoo_v17 >/dev/null
grep -q '^ODOO_IMAGE=odoo:17.0-20260630$' "${tmp_dir}/odoo17.env"

host_env="${tmp_dir}/host.env"
cp "${REPO_DIR}/.env.example" "$host_env"
COMPOSE_OUTPUT="${tmp_dir}/n8n.yml" ENV_OUTPUT="$host_env" \
  "$GENERATOR" N8N >/dev/null
grep -q '^NEW_USER=autostack$' "$host_env"
grep -q '^POSTGRES_NON_ROOT_PASSWORD=CHANGE_ME$' "$host_env"
grep -q '^N8N_IMAGE=docker.n8n.io/n8nio/n8n:2.30.5$' "$host_env"

COMPOSE_OUTPUT="${tmp_dir}/nextcloud.yml" ENV_OUTPUT="${tmp_dir}/nextcloud.env" \
  "$GENERATOR" Nginx-Proxy-Manager Nextcloud-Aio-Mastercontainer >/dev/null
grep -q '^  nextcloud-aio-mastercontainer:' "${tmp_dir}/nextcloud.yml"
grep -q '^volumes:$' "${tmp_dir}/nextcloud.yml"
grep -q '^  nextcloud_aio_mastercontainer:' "${tmp_dir}/nextcloud.yml"
grep -q '^NEXTCLOUD_AIO_IMAGE=ghcr.io/nextcloud-releases/all-in-one:latest$' "${tmp_dir}/nextcloud.env"

COMPOSE_OUTPUT="${tmp_dir}/nextcloud-classic.yml" ENV_OUTPUT="${tmp_dir}/nextcloud-classic.env" \
  "$GENERATOR" Z_Nextcloud >/dev/null
grep -q '^  redis-nextcloud:' "${tmp_dir}/nextcloud-classic.yml"
grep -q '^  nextcloud-internal:' "${tmp_dir}/nextcloud-classic.yml"
grep -q '^NEXTCLOUD_IMAGE=nextcloud:34.0.1-apache$' "${tmp_dir}/nextcloud-classic.env"
grep -q '^NEXTCLOUD_INIT_HTACCESS=true$' "${tmp_dir}/nextcloud-classic.env"

COMPOSE_OUTPUT="${tmp_dir}/nextcloud33.yml" ENV_OUTPUT="${tmp_dir}/nextcloud33.env" \
  "$GENERATOR" Z_Nextcloud/Nextcloud_v33.0.6 >/dev/null
grep -q '^NEXTCLOUD_IMAGE=nextcloud:33.0.6-apache$' "${tmp_dir}/nextcloud33.env"

COMPOSE_OUTPUT="${tmp_dir}/apisix.yml" ENV_OUTPUT="${tmp_dir}/apisix.env" \
  "$GENERATOR" APISIX >/dev/null
grep -q '^  apisix-etcd:' "${tmp_dir}/apisix.yml"
grep -q '^  apisix:' "${tmp_dir}/apisix.yml"
grep -q '^  apisix-control:' "${tmp_dir}/apisix.yml"
grep -q '^APISIX_IMAGE=apache/apisix:3.18.0-debian$' "${tmp_dir}/apisix.env"
grep -q '^APISIX_ETCD_IMAGE=quay.io/coreos/etcd:v3.5.18$' "${tmp_dir}/apisix.env"
if grep -q '^  apisix-dashboard:' "${tmp_dir}/apisix.yml"; then
  echo "La variante APISIX récente doit utiliser le Dashboard embarqué." >&2
  exit 1
fi

echo "Tests du générateur : OK"
