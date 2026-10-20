#!/usr/bin/env bash
set -Eeuo pipefail
module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"
exec docker compose -p autostack-hermes run --rm hermes "$@"
