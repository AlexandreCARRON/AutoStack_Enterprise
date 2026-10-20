#!/usr/bin/env bash
set -Eeuo pipefail
module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$module_dir/hermes_v2026.9.24"
compose=(docker compose -p autostack-hermes --profile manual)
"${compose[@]}" config --quiet
image="$("${compose[@]}" config --images)"
docker image inspect "$image" --format '{{.Architecture}} {{json .RepoDigests}}'
"${compose[@]}" run --rm -T hermes --version
"${compose[@]}" run --rm -T hermes python -c 'from hermes_cli.config import load_config; import os; c=load_config(); assert os.getuid()==10000, os.getuid(); assert c["memory"]["write_approval"] is True; assert c["memory"]["nudge_interval"]==0; assert c["skills"]["write_approval"] is True; assert c["approvals"]["mode"]=="manual"; assert c["security"]["allow_lazy_installs"] is False; assert c["kanban"]["review_dispatch"] is False; assert c["agent"]["max_turns"]==20; assert set(c["platform_toolsets"]["cli"])=={"file","todo","memory","terminal"}; print("HERMES_PILOT_VERIFIED uid=10000 approvals=manual tools=file,todo,memory,terminal memory_nudge=off")'
"${compose[@]}" run --rm -T hermes python /opt/autostack/hermes-scripts/google-workspace-carron.py self-check
"${compose[@]}" run --rm -T hermes python /opt/autostack/hermes-scripts/outlook-calendar-auth-carron.py self-check
"${compose[@]}" run --rm -T hermes python /opt/autostack/hermes-scripts/outlook-calendar-carron.py self-check
