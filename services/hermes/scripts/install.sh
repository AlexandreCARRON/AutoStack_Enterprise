#!/usr/bin/env bash
set -Eeuo pipefail
module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"
compose=(docker compose -p autostack-hermes --profile manual)
"${compose[@]}" config --quiet
if docker volume inspect autostack_hermes_data >/dev/null 2>&1; then
  echo "Existing Hermes volume: refusing to overwrite configuration. Use verify.sh." >&2
  exit 1
fi
"${compose[@]}" pull hermes
image="$("${compose[@]}" config --images)"
test "$(docker image inspect "$image" --format '{{.Architecture}}')" = "$(docker info --format '{{.Architecture}}' | sed 's/aarch64/arm64/;s/x86_64/amd64/')"
"${compose[@]}" run --rm -T hermes python -c 'from pathlib import Path; import shutil; p=Path("/opt/data"); shutil.copyfile("/opt/pilot.yaml",p/"config.yaml"); (p/"config.yaml").chmod(0o600); (p/"workspace").mkdir(exist_ok=True); print("PILOT_CONFIG_INSTALLED")'
bash "$module_dir/scripts/verify.sh"
