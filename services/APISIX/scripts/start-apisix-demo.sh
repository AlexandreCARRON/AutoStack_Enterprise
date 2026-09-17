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
readonly TLS_HELPER="${SCRIPT_DIR}/configure-docker-insecure-registries.sh"
readonly DOCKER_DAEMON_CONFIG="${AUTOSTACK_DOCKER_CONFIG_FILE:-/etc/docker/daemon.json}"
readonly DEFAULT_ADMIN_USERNAME="admin"
readonly DEFAULT_ADMIN_PASSWORD="42424242424242424242424242424242"
readonly DEFAULT_APISIX_ADMIN_KEY="${DEFAULT_ADMIN_PASSWORD}"

# Le parcours est autonome par défaut. --interactive restaure les validations humaines.
ASSUME_YES=1
RUN_SCENARIOS=1
while (($#)); do
  case "$1" in
    --yes)
      ASSUME_YES=1
      ;;
    --interactive)
      ASSUME_YES=0
      ;;
    --skip-scenarios)
      RUN_SCENARIOS=0
      ;;
    -h|--help)
      printf 'Usage : %s [--yes|--interactive] [--skip-scenarios]\n' "$0"
      exit 0
      ;;
    *)
      printf 'Option inconnue : %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

# Mémorise uniquement les exceptions TLS ajoutées par cette exécution.
TLS_EXCEPTIONS_ACTIVE=0
TEMPORARY_TLS_REGISTRIES=()
PULL_LOG=""
PREVIOUS_KEYCLOAK_ADMIN_PASSWORD=""

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

# Exécute les rares préparations système avec les privilèges déjà disponibles.
run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# Limite les modifications automatiques de l'hôte à la plateforme de démonstration.
is_debian_12() {
  [[ -r /etc/os-release ]] || return 1
  (
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "12" ]]
  )
}

# Installe les utilitaires légers attendus par les scripts ; Docker reste un prérequis.
prepare_host_tools() {
  local command_name
  local missing=()
  for command_name in python3 openssl curl jq; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  ((${#missing[@]} == 0)) && return 0

  is_debian_12 || fail "commandes manquantes : ${missing[*]} (installation automatique réservée à Debian 12)"
  command -v apt-get >/dev/null 2>&1 || fail "apt-get est requis pour installer : ${missing[*]}"
  printf 'Installation automatique des prérequis : %s\n' "${missing[*]}"
  run_as_root apt-get update
  run_as_root apt-get install -y python3 openssl curl jq ca-certificates
}

# Attend que le daemon redevienne accessible après une modification de daemon.json.
wait_for_docker() {
  local _
  for _ in {1..30}; do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  fail "Docker n'est pas redevenu disponible après son redémarrage"
}

# Retire immédiatement les seules exceptions TLS créées par cette exécution.
restore_tls_exceptions() {
  (( TLS_EXCEPTIONS_ACTIVE == 1 )) || return 0
  printf 'Réactivation de la validation TLS Docker...\n'
  if run_as_root "$TLS_HELPER" \
      --remove --yes --config "$DOCKER_DAEMON_CONFIG" -- \
      "${TEMPORARY_TLS_REGISTRIES[@]}"; then
    TLS_EXCEPTIONS_ACTIVE=0
    wait_for_docker
    printf 'Validation TLS Docker réactivée.\n'
  else
    printf '%s\n' \
      'ERREUR : la restauration TLS automatique a échoué.' \
      "Retirez manuellement les registres concernés de ${DOCKER_DAEMON_CONFIG}." >&2
    return 1
  fi
}

# Nettoie le journal temporaire et restaure TLS, y compris après une interruption.
cleanup_on_exit() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n "$PULL_LOG" && -e "$PULL_LOG" ]]; then
    rm -f -- "$PULL_LOG"
  fi
  if ! restore_tls_exceptions; then
    status=1
  fi
  exit "$status"
}

trap cleanup_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Fige le projet, le fichier d'environnement et la variante Compose de la démo.
compose() {
  docker compose \
    --project-name "$COMPOSE_PROJECT" \
    --project-directory "$SERVICE_DIR" \
    --env-file "$ENV_FILE" \
    -f "$COMPOSE_FILE" \
    "$@"
}

# Extrait uniquement les hôtes HTTPS présents dans l'erreur de pull Docker.
detect_failed_tls_registries() {
  python3 - "$PULL_LOG" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
hosts = []
for raw_url in re.findall(r"https?://[^\s\"']+", text):
    host = urlsplit(raw_url.rstrip(".,;:)]}")).netloc
    if host and re.fullmatch(r"[A-Za-z0-9.-]+(?::[0-9]+)?", host) and host not in hosts:
        hosts.append(host)

# Quay peut échouer sur son CDN après une redirection signée : les deux hôtes
# appartiennent au même téléchargement versionné par le fichier Compose.
if any(host == "quay.io" or host.endswith(".quay.io") for host in hosts):
    if "quay.io" not in hosts:
        hosts.insert(0, "quay.io")
    if "cdn01.quay.io" not in hosts:
        hosts.append("cdn01.quay.io")

for host in hosts:
    print(host)
PY
}

# Évite les doublons sans développer une liste vide sous `set -u`.
temporary_registry_contains() {
  local expected="$1"
  local existing
  for existing in "${TEMPORARY_TLS_REGISTRIES[@]-}"; do
    [[ "$existing" == "$expected" ]] && return 0
  done
  return 1
}

# Essaie d'abord avec TLS strict, puis ouvre et referme une exception ciblée sur X.509.
pull_images_with_tls_fallback() {
  mkdir -p "$RUNTIME_DIR"
  PULL_LOG="$(mktemp "${RUNTIME_DIR}/.docker-pull.XXXXXX")"
  if compose pull --ignore-buildable 2>&1 | tee "$PULL_LOG"; then
    rm -f -- "$PULL_LOG"
    PULL_LOG=""
    return 0
  fi

  if ! grep -Eqi 'x509: certificate signed by unknown authority|tls: failed to verify certificate' "$PULL_LOG"; then
    fail "docker compose pull a échoué sans erreur de certificat TLS ; consultez la sortie ci-dessus"
  fi
  is_debian_12 || fail "le contournement TLS automatique est limité à Debian 12"
  [[ -x "$TLS_HELPER" ]] || fail "assistant TLS introuvable : $TLS_HELPER"
  command -v systemctl >/dev/null 2>&1 || fail "systemctl est requis pour redémarrer Docker"

  local registry
  local configured
  local detected=()
  local requested=()
  while IFS= read -r registry; do
    [[ -n "$registry" ]] && detected+=("$registry")
  done < <(detect_failed_tls_registries)
  if [[ -n "${AUTOSTACK_TLS_REGISTRIES:-}" ]]; then
    # L'administrateur peut compléter les domaines détectés sans modifier le script.
    read -r -a requested <<<"${AUTOSTACK_TLS_REGISTRIES//,/ }"
    detected+=("${requested[@]}")
  fi
  ((${#detected[@]} > 0)) || fail "aucun domaine TLS exploitable n'a été trouvé dans l'erreur Docker"

  configured="$(run_as_root "$TLS_HELPER" --list --config "$DOCKER_DAEMON_CONFIG")"
  for registry in "${detected[@]}"; do
    if ! grep -Fxq -- "$registry" <<<"$configured" \
        && ! temporary_registry_contains "$registry"; then
      TEMPORARY_TLS_REGISTRIES+=("$registry")
    fi
  done
  ((${#TEMPORARY_TLS_REGISTRIES[@]} > 0)) || \
    fail "les domaines en erreur sont déjà non sécurisés ; installez plutôt l'autorité de certification du proxy"

  printf '%s\n' \
    'Erreur X.509 détectée pendant le pull.' \
    "Exception TLS temporaire et ciblée : ${TEMPORARY_TLS_REGISTRIES[*]}"
  run_as_root "$TLS_HELPER" \
    --add-only --yes --config "$DOCKER_DAEMON_CONFIG" -- \
    "${TEMPORARY_TLS_REGISTRIES[@]}"
  TLS_EXCEPTIONS_ACTIVE=1
  wait_for_docker

  local retry_status=0
  compose pull --ignore-buildable || retry_status=$?
  restore_tls_exceptions || retry_status=1
  (( retry_status == 0 )) || fail "le pull Docker échoue encore après le contournement TLS temporaire"
  rm -f -- "$PULL_LOG"
  PULL_LOG=""
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

# Lit une variable précise sans charger tout le fichier .env dans le shell courant.
read_env_value() {
  local key="$1"
  python3 - "$ENV_FILE" "$key" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith(f"{key}="):
        print(line.split("=", 1)[1])
        raise SystemExit(0)
raise SystemExit(1)
PY
}

# Crée le fichier privé, impose les accès administrateur de démo et génère les secrets techniques.
initialize_environment() {
  if [[ ! -f "$ENV_FILE" ]]; then
    install -m 600 "${DEMO_DIR}/.env.example" "$ENV_FILE"
    printf 'Créé : %s\n' "$ENV_FILE"
  else
    chmod 600 "$ENV_FILE"
  fi

  PREVIOUS_KEYCLOAK_ADMIN_PASSWORD="$(read_env_value KEYCLOAK_ADMIN_PASSWORD || true)"
  replace_env_value APISIX_ADMIN_KEY "$DEFAULT_APISIX_ADMIN_KEY"
  replace_env_value KEYCLOAK_ADMIN_USERNAME "$DEFAULT_ADMIN_USERNAME"
  replace_env_value KEYCLOAK_ADMIN_PASSWORD "$DEFAULT_ADMIN_PASSWORD"
  replace_env_value ELASTIC_BOOTSTRAP_PASSWORD "$DEFAULT_ADMIN_PASSWORD"
  replace_env_value ELASTIC_ADMIN_USERNAME "$DEFAULT_ADMIN_USERNAME"
  replace_env_value ELASTIC_ADMIN_PASSWORD "$DEFAULT_ADMIN_PASSWORD"
  printf 'Accès administrateur commun APISIX, Keycloak et Kibana configuré.\n'

  local key
  for key in \
    DEMO_PARTNER_API_KEY \
    DEMO_INTERNAL_API_KEY \
    DEMO_PARTNER_BACKEND_API_KEY \
    KEYCLOAK_DB_PASSWORD \
    KEYCLOAK_APISIX_CLIENT_SECRET \
    KEYCLOAK_PARTNER_CLIENT_SECRET \
    KEYCLOAK_DEMO_USER_PASSWORD \
    APISIX_OIDC_SESSION_SECRET \
    ELASTIC_KIBANA_SYSTEM_PASSWORD \
    ELASTIC_LOGSTASH_PASSWORD \
    KIBANA_SECURITY_ENCRYPTION_KEY \
    KIBANA_SAVED_OBJECTS_ENCRYPTION_KEY \
    KIBANA_REPORTING_ENCRYPTION_KEY; do
    if ! grep -Eq "^${key}=" "$ENV_FILE" || grep -Eq "^${key}=CHANGE_ME" "$ENV_FILE"; then
      replace_env_value "$key" "$(openssl rand -hex 32)"
      printf 'Secret local généré : %s\n' "$key"
    fi
  done
  replace_env_value ELASTIC_LOGSTASH_USERNAME "logstash_internal"
  replace_env_value DEMO_HOST_UID "$(id -u)"
  replace_env_value DEMO_HOST_GID "$(id -g)"
}

# Rend le mot de passe intégré Elastic déterministe, y compris avec un ancien volume non sécurisé.
prepare_elasticsearch_credentials() {
  printf "Préparation de l'authentification Elasticsearch...\n"
  compose up -d elasticsearch

  local attempt
  local elasticsearch_port
  local http_status
  elasticsearch_port="$(read_env_value ELASTICSEARCH_PORT || printf '9200')"
  for attempt in {1..90}; do
    http_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
      "http://127.0.0.1:${elasticsearch_port}/" || true)"
    [[ "$http_status" == "200" || "$http_status" == "401" ]] && break
    (( attempt == 1 || attempt % 10 == 0 )) && \
      printf "Attente d'Elasticsearch (%s/90)...\n" "$attempt"
    sleep 2
  done
  [[ "$http_status" == "200" || "$http_status" == "401" ]] || \
    fail "Elasticsearch n'est pas devenu joignable"

  if curl --fail --silent --output /dev/null \
      --user "elastic:${DEFAULT_ADMIN_PASSWORD}" \
      "http://127.0.0.1:${elasticsearch_port}/_security/_authenticate"; then
    printf 'Mot de passe Elasticsearch déjà conforme.\n'
    return 0
  fi

  printf 'Migration du mot de passe Elasticsearch existant...\n'
  printf '%s\n%s\n' "$DEFAULT_ADMIN_PASSWORD" "$DEFAULT_ADMIN_PASSWORD" | \
    compose exec -T elasticsearch \
      /usr/share/elasticsearch/bin/elasticsearch-reset-password \
      --username elastic --interactive --url http://127.0.0.1:9200 >/dev/null
  curl --fail --silent --output /dev/null \
    --user "elastic:${DEFAULT_ADMIN_PASSWORD}" \
    "http://127.0.0.1:${elasticsearch_port}/_security/_authenticate" || \
    fail "le nouveau mot de passe Elasticsearch n'a pas pu être validé"
  printf 'Mot de passe Elasticsearch réconcilié.\n'
}

# Aligne le compte master Keycloak sans effacer le realm ni la base PostgreSQL existante.
reconcile_keycloak_admin() {
  local login_script
  # L'expansion est volontairement déléguée au conteneur.
  # shellcheck disable=SC2016
  login_script='config="/tmp/autostack-kcadm-$$.config"; trap '\''rm -f -- "$config"'\'' EXIT; /opt/keycloak/bin/kcadm.sh config credentials --config "$config" --server http://127.0.0.1:8080 --realm master --user "$AUTOSTACK_ADMIN_USERNAME" --password "$AUTOSTACK_ADMIN_PASSWORD" >/dev/null'

  if compose exec -T \
      -e AUTOSTACK_ADMIN_USERNAME="$DEFAULT_ADMIN_USERNAME" \
      -e AUTOSTACK_ADMIN_PASSWORD="$DEFAULT_ADMIN_PASSWORD" \
      keycloak bash -ec "$login_script" 2>/dev/null; then
    printf 'Compte administrateur Keycloak déjà conforme.\n'
    return 0
  fi

  [[ -n "$PREVIOUS_KEYCLOAK_ADMIN_PASSWORD" \
      && "$PREVIOUS_KEYCLOAK_ADMIN_PASSWORD" != CHANGE_ME* ]] || \
    fail "impossible d'authentifier ou de migrer le compte administrateur Keycloak"

  printf 'Migration du mot de passe administrateur Keycloak existant...\n'
  # Le script et ses variables s'exécutent dans Keycloak.
  # shellcheck disable=SC2016
  compose exec -T \
    -e AUTOSTACK_ADMIN_USERNAME="$DEFAULT_ADMIN_USERNAME" \
    -e AUTOSTACK_OLD_ADMIN_PASSWORD="$PREVIOUS_KEYCLOAK_ADMIN_PASSWORD" \
    -e AUTOSTACK_NEW_ADMIN_PASSWORD="$DEFAULT_ADMIN_PASSWORD" \
    keycloak bash -ec '
      config="/tmp/autostack-kcadm-$$.config"
      trap '\''rm -f -- "$config"'\'' EXIT
      /opt/keycloak/bin/kcadm.sh config credentials \
        --config "$config" \
        --server http://127.0.0.1:8080 \
        --realm master \
        --user "$AUTOSTACK_ADMIN_USERNAME" \
        --password "$AUTOSTACK_OLD_ADMIN_PASSWORD" >/dev/null
      /opt/keycloak/bin/kcadm.sh set-password \
        --config "$config" \
        --realm master \
        --username "$AUTOSTACK_ADMIN_USERNAME" \
        --new-password "$AUTOSTACK_NEW_ADMIN_PASSWORD" >/dev/null
    ' || fail "migration du compte administrateur Keycloak impossible"
  printf 'Mot de passe administrateur Keycloak réconcilié.\n'
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
  prepare_host_tools
  require_command openssl
  require_command python3
  require_command curl
  require_command jq
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
    pull_images_with_tls_fallback
    compose build
    prepare_elasticsearch_credentials
    compose up -d --wait --wait-timeout 360
    reconcile_keycloak_admin
    # Recharge aussi les changements d'un config.yaml monté dans un conteneur existant.
    compose restart apisix
    compose --profile tools run --rm demo-configurator
  else
    fail "démarrage annulé"
  fi

  compose ps
  if (( RUN_SCENARIOS == 1 )); then
    printf '\nValidation automatique des six scénarios de démonstration...\n'
    "${SCRIPT_DIR}/run-apisix-demo-scenarios.sh"
  fi
  printf '%s\n' \
    '' \
    'Installation, configuration et validation terminées.' \
    "Utilisateur administrateur Keycloak/Kibana : ${DEFAULT_ADMIN_USERNAME}" \
    "Mot de passe administrateur et clé APISIX : ${DEFAULT_ADMIN_PASSWORD}" \
    'Pour rejouer les scénarios : ./scripts/run-apisix-demo-scenarios.sh' \
    "Console Keycloak : ${KEYCLOAK_PUBLIC_URL:-http://127.0.0.1:8080}/admin/" \
    "Parcours BFF : ${APISIX_PUBLIC_URL:-http://127.0.0.1:9080}/bff/orders"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
