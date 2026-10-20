#!/usr/bin/env bash
set -Eeuo pipefail

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"

docker compose -p autostack-hermes --profile manual run --rm -T hermes \
  bash -c 'set -Eeuo pipefail
    destination="${HERMES_HOME:-/opt/data}/skills/carron/outlook-calendar-carron"
    mkdir -p "$destination"
    cp /opt/autostack/hermes-skills/outlook-calendar-carron/SKILL.md "$destination/SKILL.md"
    chmod 700 "$(dirname "$destination")" "$destination"
    chmod 600 "$destination/SKILL.md"
    printf "%s\n" "INSTALLED $destination/SKILL.md"'
