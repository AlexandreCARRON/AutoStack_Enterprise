#!/usr/bin/env bash
set -Eeuo pipefail

if (( $# == 0 )); then
  echo "Usage: bash scripts/verify-github.sh OWNER/REPO [OWNER/REPO ...]" >&2
  exit 2
fi

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"
docker compose -p autostack-hermes --profile manual run --rm -T hermes \
  python /opt/autostack/hermes-scripts/verify-github-access.py "$@"
