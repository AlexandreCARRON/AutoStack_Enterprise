#!/usr/bin/env bash
set -Eeuo pipefail

if (( $# == 0 )); then
  echo "Usage: bash scripts/configure-github.sh OWNER/REPO [OWNER/REPO ...]" >&2
  exit 2
fi

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"
compose=(docker compose -p autostack-hermes --profile manual)

read -r -s -p "GitHub fine-grained token: " github_token
printf '\n'
trap 'unset github_token' EXIT

printf '%s' "$github_token" \
  | "${compose[@]}" run --rm -T hermes \
      python /opt/autostack/hermes-scripts/store-github-token.py
unset github_token

"${compose[@]}" run --rm -T hermes \
  git config --global --replace-all credential.https://github.com.helper \
  '!python3 /opt/autostack/hermes-scripts/git-credential-hermes-github.py'

"${compose[@]}" run --rm -T hermes \
  python /opt/autostack/hermes-scripts/verify-github-access.py "$@"
