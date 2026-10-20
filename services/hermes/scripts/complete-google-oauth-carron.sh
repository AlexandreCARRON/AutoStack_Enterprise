#!/usr/bin/env bash
set -Eeuo pipefail

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"

IFS= read -r -s -p "Colle l'URL localhost complete, puis Entrée : " oauth_callback
printf '\n'
if [[ -z "$oauth_callback" ]]; then
  printf '%s\n' "Aucune URL reçue." >&2
  exit 1
fi

printf '%s\n' "$oauth_callback" | docker compose -p autostack-hermes --profile manual run --rm -T hermes \
  python /opt/autostack/hermes-scripts/google-workspace-oauth-carron.py --auth-code-stdin
unset oauth_callback
