#!/usr/bin/env bash

set -Eeuo pipefail

readonly DEFAULT_CONFIG_FILE="/etc/docker/daemon.json"
readonly DEFAULT_REGISTRIES=("quay.io" "cdn01.quay.io")

CONFIG_FILE="$DEFAULT_CONFIG_FILE"
MODE="add"
RESTART_DOCKER=1
ASSUME_YES=0
REGISTRIES=()

usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/idempotent/configure-docker-insecure-registries.sh [options] [registre...]

Ajoute des hôtes à insecure-registries dans /etc/docker/daemon.json.
Sans registre explicite, quay.io et cdn01.quay.io sont configurés.

Options:
  --remove       Retirer les registres au lieu de les ajouter.
  --yes          Ne pas demander de confirmation.
  --no-restart   Modifier le fichier sans redémarrer Docker.
  --config PATH  Utiliser un autre daemon.json.
  -h, --help     Afficher cette aide.

Exemples:
  sudo ./scripts/idempotent/configure-docker-insecure-registries.sh --yes
  sudo ./scripts/idempotent/configure-docker-insecure-registries.sh --yes registry.example.net
  sudo ./scripts/idempotent/configure-docker-insecure-registries.sh --remove --yes
EOF
}

fail() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --remove)
      MODE="remove"
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --no-restart)
      RESTART_DOCKER=0
      shift
      ;;
    --config)
      (($# >= 2)) || fail "--config exige un chemin."
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      REGISTRIES+=("$@")
      break
      ;;
    -*)
      fail "option inconnue : $1"
      ;;
    *)
      REGISTRIES+=("$1")
      shift
      ;;
  esac
done

if ((${#REGISTRIES[@]} == 0)); then
  REGISTRIES=("${DEFAULT_REGISTRIES[@]}")
fi

for registry in "${REGISTRIES[@]}"; do
  if [[ ! "$registry" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
    fail "registre invalide : $registry"
  fi
done

readonly OS_RELEASE_FILE="${AUTOSTACK_OS_RELEASE_FILE:-/etc/os-release}"
[[ -r "$OS_RELEASE_FILE" ]] || fail "impossible de lire $OS_RELEASE_FILE."

# shellcheck disable=SC1090
. "$OS_RELEASE_FILE"
if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "12" ]]; then
  fail "ce script prend uniquement en charge Debian 12."
fi

command -v python3 >/dev/null 2>&1 || \
  fail "python3 est requis (sudo apt install python3)."

if [[ "$CONFIG_FILE" == /etc/* && "$EUID" -ne 0 ]]; then
  fail "relancez ce script avec sudo."
fi

if ((RESTART_DOCKER)) && [[ "$EUID" -ne 0 ]]; then
  fail "le redémarrage de Docker exige sudo."
fi

if [[ "$MODE" == "remove" && ! -e "$CONFIG_FILE" ]]; then
  printf 'Aucune configuration à modifier dans %s.\n' "$CONFIG_FILE"
  exit 0
fi

if [[ "$MODE" == "add" && "$ASSUME_YES" -eq 0 ]]; then
  printf '%s\n' \
    'AVERTISSEMENT : cette configuration désactive la validation TLS' \
    'pour les registres indiqués et convient uniquement à un contournement temporaire.'
  printf 'Registres : %s\n' "${REGISTRIES[*]}"
  read -r -p 'Continuer ? [oui/N] ' answer
  case "${answer,,}" in
    oui|o|yes|y) ;;
    *)
      printf 'Opération annulée.\n'
      exit 0
      ;;
  esac
fi

readonly CONFIG_DIR="$(dirname -- "$CONFIG_FILE")"
mkdir -p -- "$CONFIG_DIR"
TEMP_CONFIG="$(mktemp "${CONFIG_DIR}/.daemon.json.XXXXXX")"
trap 'rm -f -- "$TEMP_CONFIG"' EXIT

python3 - "$CONFIG_FILE" "$TEMP_CONFIG" "$MODE" "${REGISTRIES[@]}" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
mode = sys.argv[3]
requested = sys.argv[4:]

try:
    if source.exists() and source.stat().st_size:
        with source.open(encoding="utf-8") as stream:
            config = json.load(stream)
    else:
        config = {}
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"Erreur : configuration Docker illisible : {error}")

if not isinstance(config, dict):
    raise SystemExit("Erreur : daemon.json doit contenir un objet JSON.")

current = config.get("insecure-registries", [])
if not isinstance(current, list) or not all(isinstance(item, str) for item in current):
    raise SystemExit("Erreur : insecure-registries doit être une liste de chaînes.")

if mode == "add":
    for registry in requested:
        if registry not in current:
            current.append(registry)
    config["insecure-registries"] = current
else:
    current = [registry for registry in current if registry not in requested]
    if current:
        config["insecure-registries"] = current
    else:
        config.pop("insecure-registries", None)

with destination.open("w", encoding="utf-8") as stream:
    json.dump(config, stream, indent=2, sort_keys=True)
    stream.write("\n")
PY

if [[ -f "$CONFIG_FILE" ]] && cmp -s -- "$CONFIG_FILE" "$TEMP_CONFIG"; then
  printf 'Configuration déjà à jour : %s\n' "$CONFIG_FILE"
  exit 0
fi

if command -v dockerd >/dev/null 2>&1; then
  dockerd --validate --config-file="$TEMP_CONFIG" >/dev/null
elif ((RESTART_DOCKER)); then
  fail "dockerd est introuvable ; Docker Engine est-il installé ?"
else
  printf 'Avertissement : validation dockerd non exécutée.\n' >&2
fi

BACKUP_FILE=""
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP_FILE="${CONFIG_FILE}.backup.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -a -- "$CONFIG_FILE" "$BACKUP_FILE"
  printf 'Sauvegarde créée : %s\n' "$BACKUP_FILE"
fi

install -m 0644 -- "$TEMP_CONFIG" "$CONFIG_FILE"
printf 'Configuration mise à jour : %s\n' "$CONFIG_FILE"

if ((RESTART_DOCKER)); then
  if ! systemctl restart docker; then
    printf 'Échec du redémarrage de Docker ; restauration en cours.\n' >&2
    if [[ -n "$BACKUP_FILE" ]]; then
      cp -a -- "$BACKUP_FILE" "$CONFIG_FILE"
    else
      rm -f -- "$CONFIG_FILE"
    fi
    systemctl restart docker || true
    fail "configuration annulée après échec du redémarrage."
  fi
  printf 'Docker redémarré avec succès.\n'
else
  printf "Docker n'a pas été redémarré (--no-restart).\n"
fi

if [[ "$MODE" == "add" ]]; then
  printf 'Validation TLS désactivée pour : %s\n' "${REGISTRIES[*]}"
else
  printf 'Registres retirés de insecure-registries : %s\n' "${REGISTRIES[*]}"
fi
