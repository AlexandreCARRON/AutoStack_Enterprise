#!/usr/bin/env bash

# Ouvre puis retire des exceptions TLS Docker limitées à des registres explicites.
# Ce contournement Debian 12 est temporaire, sauvegardé et réversible ; le mode
# guidé tente aussi de restaurer TLS lorsqu'une interruption est détectée.

set -Eeuo pipefail

# Les valeurs par défaut couvrent le registre et le CDN observés lors du pull APISIX.
readonly DEFAULT_CONFIG_FILE="/etc/docker/daemon.json"
readonly DEFAULT_REGISTRIES=("quay.io" "cdn01.quay.io")
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH

# Ces variables décrivent l'action demandée et l'état du workflow interactif courant.
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
ACTION="guided"
RESTART_DOCKER=1
ASSUME_YES=0
REGISTRIES=()
WORKFLOW_REGISTRIES=()
TLS_EXCEPTIONS_ACTIVE=0

# Documente les modes guidé et non interactifs sans modifier le système.
usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/configure-docker-insecure-registries.sh [options] [registre...]

Sans option, lance un assistant interactif qui ouvre temporairement les
registres nécessaires, attend la fin du pull, réactive TLS puis démarre Compose.

Options:
  --add-only     Ajouter les registres sans lancer l'assistant interactif.
  --remove       Retirer les registres sans lancer l'assistant interactif.
  --yes          Ne pas demander de confirmation.
  --no-restart   Modifier le fichier sans redémarrer Docker.
  --config PATH  Utiliser un autre daemon.json.
  -h, --help     Afficher cette aide.

Exemples:
  sudo ./scripts/configure-docker-insecure-registries.sh
  sudo ./scripts/configure-docker-insecure-registries.sh --add-only --yes registry.example.net
  sudo ./scripts/configure-docker-insecure-registries.sh --remove --yes
EOF
}

# Interrompt le script avec un message cohérent sur stderr.
fail() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

# Accepte les réponses usuelles françaises et anglaises, avec Oui comme défaut.
confirm() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "${prompt} [Y/n] " answer
    case "$answer" in
      ""|[yY]|[yY][eE][sS]|[oO]|[oO][uU][iI]) return 0 ;;
      [nN]|[nN][oO]|[nN][oO][nN]) return 1 ;;
      *) printf 'Répondez par Y ou n.\n' ;;
    esac
  done
}

# Refuse les chemins et schémas : Docker attend ici uniquement hôte[:port].
validate_registries() {
  local registry
  for registry in "$@"; do
    if [[ ! "$registry" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
      fail "registre invalide : $registry"
    fi
  done
}

# Sur interruption, retire les seules exceptions ouvertes par le workflow courant.
restore_tls_on_exit() {
  local status=$?
  trap - EXIT INT TERM

  if ((TLS_EXCEPTIONS_ACTIVE)); then
    printf '\nInterruption détectée : réactivation de TLS avant de quitter.\n' >&2
    local options=(--remove --yes --config "$CONFIG_FILE")
    if ((!RESTART_DOCKER)); then
      options+=(--no-restart)
    fi
    "$SCRIPT_PATH" "${options[@]}" -- "${WORKFLOW_REGISTRIES[@]}" || \
      printf 'ERREUR : TLS doit être réactivé manuellement.\n' >&2
  fi

  exit "$status"
}

# Encadre l'ouverture temporaire, l'attente du pull puis la restauration de TLS.
guided_workflow() {
  local known_domains
  local domains_input
  local options

  printf '%s\n' \
    'Cet assistant redémarre Docker puis attend pendant que vous effectuez le pull' \
    'dans une autre fenêtre shell. Il réactive ensuite TLS automatiquement.'

  if ! confirm 'Avez-vous lancé ce script dans une nouvelle fenêtre shell ?'; then
    printf 'Ouvrez une nouvelle fenêtre shell, puis relancez le script.\n'
    return 1
  fi

  if confirm 'Connaissez-vous déjà les domaines dont le certificat TLS est refusé ?'; then
    known_domains=1
  else
    known_domains=0
    printf '%s\n' \
      "Dans l'autre fenêtre, lancez : sudo docker compose pull" \
      'Repérez chaque URL associée à "x509: certificate signed by unknown authority".' \
      'Le domaine est la partie située après https:// et avant le prochain /.' \
      'Exemple : https://cdn01.quay.io/... donne cdn01.quay.io.'
    read -r -p 'Appuyez sur Entrée après avoir relevé les domaines. '
  fi

  while true; do
    if ((known_domains)); then
      printf 'Domaines connus, séparés par des espaces ou des virgules\n'
    else
      printf 'Domaines relevés, séparés par des espaces ou des virgules\n'
    fi
    read -r -p '[quay.io cdn01.quay.io] : ' domains_input
    domains_input="${domains_input//,/ }"
    if [[ -z "${domains_input//[[:space:]]/}" ]]; then
      WORKFLOW_REGISTRIES=("${DEFAULT_REGISTRIES[@]}")
    else
      read -r -a WORKFLOW_REGISTRIES <<<"$domains_input"
    fi
    validate_registries "${WORKFLOW_REGISTRIES[@]}"
    printf 'Domaines qui seront temporairement autorisés : %s\n' \
      "${WORKFLOW_REGISTRIES[*]}"
    if confirm 'Validez-vous cette liste ?'; then
      break
    fi
  done

  if ! confirm 'Modifier daemon.json et redémarrer Docker maintenant ?'; then
    printf 'Aucune modification effectuée.\n'
    return 0
  fi

  options=(--add-only --yes --config "$CONFIG_FILE")
  if ((!RESTART_DOCKER)); then
    options+=(--no-restart)
  fi
  "$SCRIPT_PATH" "${options[@]}" -- "${WORKFLOW_REGISTRIES[@]}"
  TLS_EXCEPTIONS_ACTIVE=1

  # Le piège EXIT constitue le filet de sécurité tant que les exceptions sont actives.
  trap restore_tls_on_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  printf '\nTLS est temporairement désactivé pour les domaines sélectionnés.\n'
  printf '%s\n' \
    "Dans l'autre fenêtre shell, terminez maintenant le téléchargement ou" \
    "l'installation, par exemple avec : sudo docker compose pull"
  read -r -p 'Une fois terminé, tapez un mot ou appuyez sur Entrée : '

  while ! confirm 'Réactiver TLS et redémarrer Docker maintenant ?'; do
    printf '%s\n' \
      'TLS reste temporairement désactivé.' \
      "Terminez vos opérations dans l'autre fenêtre avant de continuer."
    read -r -p 'Appuyez sur Entrée lorsque vous êtes prêt. '
  done

  options=(--remove --yes --config "$CONFIG_FILE")
  if ((!RESTART_DOCKER)); then
    options+=(--no-restart)
  fi
  "$SCRIPT_PATH" "${options[@]}" -- "${WORKFLOW_REGISTRIES[@]}"
  TLS_EXCEPTIONS_ACTIVE=0
  trap - EXIT INT TERM

  if ! confirm 'Démarrer ou réconcilier la stack Docker Compose APISIX ?'; then
    printf 'TLS est réactivé. Démarrage Compose non demandé.\n'
    return 0
  fi

  "${SCRIPT_DIR}/install-APISIX.sh"
}

# Analyse les options avant les contrôles système afin que --help reste toujours disponible.
while (($#)); do
  case "$1" in
    --add-only)
      ACTION="add"
      shift
      ;;
    --remove)
      ACTION="remove"
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

# Restreint ce changement de daemon Docker à la plateforme explicitement testée.
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

# Le mode guidé réutilise ce même script pour les opérations add/remove idempotentes.
if [[ "$ACTION" == "guided" ]]; then
  if ((ASSUME_YES)); then
    fail "--yes exige --add-only ou --remove."
  fi
  guided_workflow
  exit $?
fi

if ((${#REGISTRIES[@]} == 0)); then
  REGISTRIES=("${DEFAULT_REGISTRIES[@]}")
fi
validate_registries "${REGISTRIES[@]}"

# Retirer une exception d'un fichier absent est déjà l'état final recherché.
if [[ "$ACTION" == "remove" && ! -e "$CONFIG_FILE" ]]; then
  printf 'Aucune configuration à modifier dans %s.\n' "$CONFIG_FILE"
  exit 0
fi

# Le mode add interactif rappelle explicitement la baisse temporaire de sécurité.
if [[ "$ACTION" == "add" && "$ASSUME_YES" -eq 0 ]]; then
  printf '%s\n' \
    'AVERTISSEMENT : cette configuration désactive la validation TLS' \
    'pour les registres indiqués et convient uniquement à un contournement temporaire.'
  printf 'Registres : %s\n' "${REGISTRIES[*]}"
  read -r -p 'Continuer ? [oui/N] ' answer
  case "$answer" in
    [oO][uU][iI]|[oO]|[yY][eE][sS]|[yY]) ;;
    *)
      printf 'Opération annulée.\n'
      exit 0
      ;;
  esac
fi

# Prépare la nouvelle configuration dans le même dossier pour permettre un remplacement sûr.
CONFIG_DIR="$(dirname -- "$CONFIG_FILE")"
readonly CONFIG_DIR
mkdir -p -- "$CONFIG_DIR"
TEMP_CONFIG="$(mktemp "${CONFIG_DIR}/.daemon.json.XXXXXX")"
trap 'rm -f -- "$TEMP_CONFIG"' EXIT

# Préserve toutes les clés Docker étrangères et ne modifie que insecure-registries.
python3 - "$CONFIG_FILE" "$TEMP_CONFIG" "$ACTION" "${REGISTRIES[@]}" <<'PY'
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

# Une exécution répétée ne redémarre pas Docker lorsque la cible est déjà conforme.
if [[ -f "$CONFIG_FILE" ]] && cmp -s -- "$CONFIG_FILE" "$TEMP_CONFIG"; then
  printf 'Configuration déjà à jour : %s\n' "$CONFIG_FILE"
  exit 0
fi

# Demande au daemon de valider le JSON avant de toucher à sa configuration active.
if command -v dockerd >/dev/null 2>&1; then
  dockerd --validate --config-file="$TEMP_CONFIG" >/dev/null
elif ((RESTART_DOCKER)); then
  fail "dockerd est introuvable ; Docker Engine est-il installé ?"
else
  printf 'Avertissement : validation dockerd non exécutée.\n' >&2
fi

# Conserve une sauvegarde horodatée avant toute modification d'un fichier existant.
BACKUP_FILE=""
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP_FILE="${CONFIG_FILE}.backup.$(date -u +%Y%m%dT%H%M%SZ).${BASHPID:-$$}"
  cp -a -- "$CONFIG_FILE" "$BACKUP_FILE"
  printf 'Sauvegarde créée : %s\n' "$BACKUP_FILE"
fi

install -m 0644 -- "$TEMP_CONFIG" "$CONFIG_FILE"
printf 'Configuration mise à jour : %s\n' "$CONFIG_FILE"

# En cas d'échec du redémarrage, restaure immédiatement l'état Docker précédent.
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

if [[ "$ACTION" == "add" ]]; then
  printf 'Validation TLS désactivée pour : %s\n' "${REGISTRIES[*]}"
else
  printf 'Registres retirés de insecure-registries : %s\n' "${REGISTRIES[*]}"
fi
