#!/usr/bin/env bash

set -Eeuo pipefail

# Persiste le prérequis Elasticsearch sans ajouter plusieurs fois la même ligne.
readonly SYSCTL_FILE="/etc/sysctl.d/99-elasticsearch.conf"
printf '%s\n' 'vm.max_map_count=262144' | sudo tee "$SYSCTL_FILE" >/dev/null

# Charge uniquement le fichier géré par ce script.
sudo sysctl -p "$SYSCTL_FILE"
