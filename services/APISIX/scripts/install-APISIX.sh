#!/usr/bin/env bash

# Installe la variante APISIX maintenue à partir de son fichier Compose versionné.
# Le script reste relançable : Compose réconcilie l'état existant et les secrets
# locaux sont conservés dans un fichier .env non versionné.

set -Eeuo pipefail

# Résout tous les chemins depuis le service afin que son dossier soit autonome.
SERVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SERVICE_DIR
export AUTOSTACK_APISIX_DIR="$SERVICE_DIR"
readonly VARIANT_DIR="${SERVICE_DIR}/APISIX_v3.18.0"
readonly ENV_FILE="${APISIX_ENV_FILE:-${VARIANT_DIR}/.env}"

# Initialise une configuration privée mais impose une édition manuelle des secrets.
if [[ ! -f "$ENV_FILE" ]]; then
  cp -- "${VARIANT_DIR}/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  printf 'Configuration créée : %s\n' "$ENV_FILE"
  printf 'Remplacez APISIX_ADMIN_KEY, puis relancez ce script.\n' >&2
  exit 1
fi

# Refuse tout déploiement qui utiliserait encore les marqueurs publics du modèle.
if grep -Eq '^[A-Z0-9_]+=.*CHANGE_ME' "$ENV_FILE"; then
  printf 'Erreur : remplacez toutes les valeurs CHANGE_ME dans %s.\n' "$ENV_FILE" >&2
  exit 1
fi

# Valide la résolution complète de Compose avant tout téléchargement ou démarrage.
docker compose \
  --project-directory "$SERVICE_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  config --quiet

# Télécharge explicitement les images pour isoler les erreurs réseau du démarrage.
docker compose \
  --project-directory "$SERVICE_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  pull

# Réconcilie les conteneurs et attend la réussite de leurs contrôles de santé.
docker compose \
  --project-directory "$SERVICE_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  up -d --wait

# Affiche l'état final pour rendre le résultat immédiatement vérifiable.
docker compose \
  --project-directory "$SERVICE_DIR" \
  --env-file "$ENV_FILE" \
  -f "${VARIANT_DIR}/docker-compose.yml" \
  ps
