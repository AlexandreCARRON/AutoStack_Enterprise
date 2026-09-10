#!/usr/bin/env bash

# Exécute les quatre preuves fonctionnelles de la démo APISIX déjà démarrée.
# Chaque assertion échoue avec un code non nul afin d'être réutilisable en CI.

set -Eeuo pipefail

# Les chemins sont ancrés sur le dépôt, indépendamment du dossier de lancement.
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly DEMO_DIR="${REPO_DIR}/services/APISIX/APISIX_demo_v3.18.0"
readonly ENV_FILE="${DEMO_DIR}/.env"

# Uniformise les erreurs attendues par un utilisateur ou un appel automatisé.
fail() {
  printf 'ÉCHEC : %s\n' "$*" >&2
  exit 1
}

# Vérifie l'environnement avant d'émettre la première requête de démonstration.
[[ -f "$ENV_FILE" ]] || fail "${ENV_FILE} absent ; lancez d'abord ./scripts/start-apisix-demo.sh"
command -v curl >/dev/null 2>&1 || fail "curl est requis"
command -v jq >/dev/null 2>&1 || fail "jq est requis"
command -v docker >/dev/null 2>&1 || fail "docker est requis"

# Exporte temporairement les variables requises par les clients Compose et les URLs locales.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

readonly ELASTICSEARCH_URL="${ELASTICSEARCH_DEMO_BASE_URL:-http://127.0.0.1:${ELASTICSEARCH_PORT:-9200}}"

# Conserve la réponse négative dans un fichier éphémère supprimé à toute sortie.
unauthorized_response="$(mktemp)"
trap 'rm -f -- "$unauthorized_response"' EXIT

# Réutilise exactement le même projet et la même variante que le script de démarrage.
compose=(
  docker compose
  --project-name autostack-apisix-demo
  --project-directory "$REPO_DIR"
  --env-file "$ENV_FILE"
  -f "${DEMO_DIR}/docker-compose.yml"
  --profile tools
)

printf '\n1/4 - Requête partenaire sans clé : APISIX doit refuser\n'
"${compose[@]}" run --rm --no-deps partner-client --without-key --expected-status 401 >"$unauthorized_response"
printf 'OK : HTTP 401\n'

printf '\n2/4 - Partenaire -> APISIX -> API interne fictive\n'
partner_response="$("${compose[@]}" run --rm --no-deps partner-client)"
jq -e '.service == "api-interne-commandes" and .request.consumer == "partenaire_A"' \
  <<<"$partner_response" >/dev/null
printf "OK : authentification key-auth et réponse de l’API interne\n"

printf '\n3/4 - SI interne -> APISIX -> partenaire HTTPS/mTLS\n'
si_response="$("${compose[@]}" run --rm --no-deps si-client)"
jq -e '.service == "backend-partenaire-a" and .status == "AVAILABLE" and .mtls_client != null' \
  <<<"$si_response" >/dev/null
printf 'OK : le partenaire a reçu le certificat client présenté par APISIX\n'

printf '\n4/4 - APISIX -> Logstash -> Elasticsearch\n'
count=0
# Le pipeline de journalisation est asynchrone : cette boucle borne son éventuelle cohérence.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  count="$(curl --fail --silent --show-error \
    "${ELASTICSEARCH_URL}/apisix-demo-*/_count" 2>/dev/null | jq -r '.count // 0' || printf '0')"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  (( count >= 2 )) && break
  sleep 2
done
(( count >= 2 )) || fail "aucun journal APISIX trouvé dans Elasticsearch"
printf 'OK : %s événements au minimum dans apisix-demo-*\n' "$count"

printf '\nTous les scénarios sont validés.\n'
printf 'Dashboard APISIX : http://127.0.0.1:%s/ui/\n' "${APISIX_ADMIN_PORT:-9180}"
printf 'Kibana : http://127.0.0.1:%s/app/discover\n' "${KIBANA_PORT:-5601}"
