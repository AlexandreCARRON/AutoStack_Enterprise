#!/usr/bin/env bash

# Prépare et démarre l'environnement de démonstration APISIX de bout en bout.
# Les secrets, certificats et objets générés restent dans runtime/ ou .env,
# deux emplacements locaux exclus du versionnement.

set -Eeuo pipefail

# Résout toutes les ressources depuis la racine du service copié.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SERVICE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly SERVICE_DIR
export AUTOSTACK_APISIX_DIR="$SERVICE_DIR"
readonly DEMO_DIR="${SERVICE_DIR}/APISIX_demo_v3.18.0"
readonly ENV_FILE="${DEMO_DIR}/.env"
readonly COMPOSE_FILE="${DEMO_DIR}/docker-compose.yml"
readonly WORKBOOK="${SERVICE_DIR}/APISIX_v3.18.0/fichiers/AutoStack_Demo_APISIX.xlsx"
readonly RUNTIME_DIR="${DEMO_DIR}/runtime"
readonly CERT_DIR="${RUNTIME_DIR}/certs"
readonly GENERATED_DIR="${RUNTIME_DIR}/generated"
readonly COMPOSE_PROJECT="autostack-apisix-demo"

# --yes rend uniquement les confirmations non interactives ; les validations restent actives.
ASSUME_YES=0
if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=1
elif (( $# > 0 )); then
  printf 'Usage : %s [--yes]\n' "$0" >&2
  exit 2
fi

# Arrête immédiatement le scénario avec un message homogène et exploitable.
fail() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

# Vérifie les dépendances hôte avant de créer le moindre artefact local.
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "commande requise introuvable : $1"
}

# Centralise les validations utilisateur pour conserver le même mode interactif partout.
confirm() {
  local prompt="$1"
  local answer
  if (( ASSUME_YES == 1 )); then
    return 0
  fi
  read -r -p "${prompt} [Y/n] " answer
  [[ -z "$answer" || "$answer" =~ ^[YyOo]$ ]]
}

# Fige le projet, le fichier d'environnement et la variante Compose de la démo.
compose() {
  docker compose \
    --project-name "$COMPOSE_PROJECT" \
    --project-directory "$SERVICE_DIR" \
    --env-file "$ENV_FILE" \
    -f "$COMPOSE_FILE" \
    "$@"
}

# Remplace une variable précise sans exposer ni réordonner les autres secrets du fichier.
replace_env_value() {
  local key="$1"
  local value="$2"
  python3 - "$ENV_FILE" "$key" "$value" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines()
replacement = f"{key}={value}"
for index, line in enumerate(lines):
    if line.startswith(f"{key}="):
        lines[index] = replacement
        break
else:
    lines.append(replacement)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

# Crée le fichier privé et ne régénère que les secrets absents ou encore factices.
initialize_environment() {
  if [[ ! -f "$ENV_FILE" ]]; then
    install -m 600 "${DEMO_DIR}/.env.example" "$ENV_FILE"
    printf 'Créé : %s\n' "$ENV_FILE"
  else
    chmod 600 "$ENV_FILE"
  fi

  local key
  for key in APISIX_ADMIN_KEY DEMO_PARTNER_API_KEY DEMO_INTERNAL_API_KEY DEMO_PARTNER_BACKEND_API_KEY; do
    if ! grep -Eq "^${key}=" "$ENV_FILE" || grep -Eq "^${key}=CHANGE_ME" "$ENV_FILE"; then
      replace_env_value "$key" "$(openssl rand -hex 32)"
      printf 'Secret local généré : %s\n' "$key"
    fi
  done
  replace_env_value DEMO_HOST_UID "$(id -u)"
  replace_env_value DEMO_HOST_GID "$(id -g)"
}

# Réutilise les certificats valides ; sinon recrée une PKI locale cohérente pour le mTLS.
generate_certificates() {
  local partner_host="$1"
  mkdir -p "$CERT_DIR"
  if [[ -s "${CERT_DIR}/demo-ca.crt" \
        && -s "${CERT_DIR}/partner-server.crt" \
        && -s "${CERT_DIR}/partner-server.key" \
        && -s "${CERT_DIR}/apisix-client.crt" \
        && -s "${CERT_DIR}/apisix-client.key" ]] \
      && openssl verify -CAfile "${CERT_DIR}/demo-ca.crt" \
        "${CERT_DIR}/partner-server.crt" "${CERT_DIR}/apisix-client.crt" >/dev/null 2>&1; then
    if openssl x509 -in "${CERT_DIR}/partner-server.crt" -noout -checkhost "$partner_host" >/dev/null 2>&1; then
      printf 'Certificats mTLS déjà valides : %s\n' "$CERT_DIR"
      return
    fi
  fi

  # Supprime uniquement les artefacts gérés par la démo avant leur régénération atomique.
  local server_ext="${CERT_DIR}/partner-server.ext"
  local client_ext="${CERT_DIR}/apisix-client.ext"
  rm -f -- \
    "${CERT_DIR}/demo-ca.crt" "${CERT_DIR}/demo-ca.key" "${CERT_DIR}/demo-ca.srl" \
    "${CERT_DIR}/partner-server.crt" "${CERT_DIR}/partner-server.key" "${CERT_DIR}/partner-server.csr" \
    "${CERT_DIR}/apisix-client.crt" "${CERT_DIR}/apisix-client.key" "${CERT_DIR}/apisix-client.csr" \
    "$server_ext" "$client_ext"

  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 30 \
    -subj "/CN=AutoStack Demo CA" \
    -keyout "${CERT_DIR}/demo-ca.key" \
    -out "${CERT_DIR}/demo-ca.crt" >/dev/null 2>&1

  openssl req -newkey rsa:2048 -nodes -sha256 \
    -subj "/CN=${partner_host}" \
    -keyout "${CERT_DIR}/partner-server.key" \
    -out "${CERT_DIR}/partner-server.csr" >/dev/null 2>&1
  printf '%s\n' \
    "subjectAltName=DNS:partner-api,DNS:${partner_host}" \
    'extendedKeyUsage=serverAuth' > "$server_ext"
  openssl x509 -req -sha256 -days 30 \
    -in "${CERT_DIR}/partner-server.csr" \
    -CA "${CERT_DIR}/demo-ca.crt" \
    -CAkey "${CERT_DIR}/demo-ca.key" \
    -CAcreateserial \
    -extfile "$server_ext" \
    -out "${CERT_DIR}/partner-server.crt" >/dev/null 2>&1

  openssl req -newkey rsa:2048 -nodes -sha256 \
    -subj "/CN=apisix-demo-client" \
    -keyout "${CERT_DIR}/apisix-client.key" \
    -out "${CERT_DIR}/apisix-client.csr" >/dev/null 2>&1
  printf '%s\n' 'extendedKeyUsage=clientAuth' > "$client_ext"
  openssl x509 -req -sha256 -days 30 \
    -in "${CERT_DIR}/apisix-client.csr" \
    -CA "${CERT_DIR}/demo-ca.crt" \
    -CAkey "${CERT_DIR}/demo-ca.key" \
    -CAcreateserial \
    -extfile "$client_ext" \
    -out "${CERT_DIR}/apisix-client.crt" >/dev/null 2>&1

  rm -f -- "${CERT_DIR}/partner-server.csr" "${CERT_DIR}/apisix-client.csr" "$server_ext" "$client_ext"
  chmod 600 "${CERT_DIR}"/*.key
  openssl verify -CAfile "${CERT_DIR}/demo-ca.crt" \
    "${CERT_DIR}/partner-server.crt" "${CERT_DIR}/apisix-client.crt" >/dev/null
  printf 'Certificats mTLS générés : %s\n' "$CERT_DIR"
}

# Elasticsearch exige cette limite noyau sur Linux ; aucune modification n'est faite ailleurs.
prepare_elasticsearch_host() {
  [[ "$(uname -s)" == "Linux" ]] || return 0
  local current
  current="$(sysctl -n vm.max_map_count 2>/dev/null || printf '0')"
  if (( current >= 1048576 )); then
    return 0
  fi
  printf 'Elasticsearch 9 recommande vm.max_map_count=1048576 (actuel : %s).\n' "$current"
  if confirm "Appliquer cette valeur jusqu'au prochain redémarrage ?"; then
    sudo sysctl -w vm.max_map_count=1048576 >/dev/null
  else
    fail "prérequis Elasticsearch refusé ; relancez après sudo sysctl -w vm.max_map_count=1048576"
  fi
}

# Orchestre les prérequis, la génération, le démarrage puis le bootstrap fonctionnel.
main() {
  require_command docker
  require_command openssl
  require_command python3
  docker info >/dev/null 2>&1 || fail "Docker n'est pas démarré ou l'utilisateur n'a pas accès au daemon"
  docker compose version >/dev/null 2>&1 || fail "le plugin Docker Compose est indisponible"
  [[ -f "$WORKBOOK" ]] || fail "classeur introuvable : $WORKBOOK"

  initialize_environment
  mkdir -p "$GENERATED_DIR"
  python3 "${SCRIPT_DIR}/generate-apisix-demo-config.py" "$WORKBOOK" "$GENERATED_DIR"

  # Le manifeste généré reste la source de vérité pour le DNS et le port du partenaire.
  read -r partner_host partner_port < <(
    python3 - "${GENERATED_DIR}/manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
print(manifest["backend"]["HOST"], manifest["backend"]["PORT"])
PY
  )
  replace_env_value DEMO_PARTNER_HOST "$partner_host"
  replace_env_value DEMO_PARTNER_PORT "$partner_port"
  generate_certificates "$partner_host"
  prepare_elasticsearch_host

  # La validation Compose précède toute opération réseau ou création de conteneur.
  compose config --quiet
  if confirm "Télécharger/construire les images et démarrer la démonstration ?"; then
    compose pull --ignore-buildable
    compose build
    compose up -d --wait --wait-timeout 360
    compose --profile tools run --rm demo-configurator
  else
    fail "démarrage annulé"
  fi

  compose ps
  printf '\nDémonstration prête. Lancez depuis la racine du service :\n  ./scripts/run-apisix-demo-scenarios.sh\n'
}

main "$@"
