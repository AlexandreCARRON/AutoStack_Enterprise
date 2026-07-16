#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_OUTPUT="${COMPOSE_OUTPUT:-${REPO_DIR}/docker-compose.yml}"
readonly ENV_OUTPUT="${ENV_OUTPUT:-${REPO_DIR}/.env}"
readonly FORCE="${FORCE:-0}"

usage() {
  cat <<'EOF'
Usage: ./generate-docker-compose.sh service1 [service2 ...]

Variables optionnelles :
  COMPOSE_OUTPUT  Chemin du fichier Compose généré.
  ENV_OUTPUT      Chemin du fichier d'environnement.
  FORCE=1         Autorise le remplacement du fichier Compose existant.

Exemple :
  ./generate-docker-compose.sh Nginx-Proxy-Manager Odoo
EOF
}

fail() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

if (( $# == 0 )); then
  usage >&2
  exit 1
fi

if [[ -e "$COMPOSE_OUTPUT" && "$FORCE" != "1" ]]; then
  fail "$COMPOSE_OUTPUT existe déjà. Relancez avec FORCE=1 pour le remplacer."
fi

[[ -d "$(dirname -- "$COMPOSE_OUTPUT")" ]] || fail "le dossier de sortie Compose n'existe pas"
[[ -d "$(dirname -- "$ENV_OUTPUT")" ]] || fail "le dossier de sortie .env n'existe pas"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

compose_tmp="${tmp_dir}/docker-compose.yml"
env_tmp="${tmp_dir}/.env"
required_vars="${tmp_dir}/required-vars"
selected_services_file="${tmp_dir}/selected-services"
extras_dir="${tmp_dir}/extras"

printf 'services:\n' > "$compose_tmp"
: > "$env_tmp"
: > "$required_vars"
: > "$selected_services_file"
mkdir "$extras_dir"

if [[ -f "${REPO_DIR}/.env.example" ]]; then
  cat "${REPO_DIR}/.env.example" >> "$env_tmp"
fi

for service in "$@"; do
  [[ "$service" =~ ^[A-Za-z0-9._-]+$ ]] || fail "nom de service invalide : $service"
  if grep -Fxq -- "$service" "$selected_services_file"; then
    fail "service sélectionné plusieurs fois : $service"
  fi
  printf '%s\n' "$service" >> "$selected_services_file"

  service_dir="${REPO_DIR}/services/${service}"
  [[ -d "$service_dir" ]] || fail "service introuvable : $service"

  compose_source="${service_dir}/docker-compose.yml"
  if [[ ! -f "$compose_source" && -f "${service_dir}/dockercompose.yml" ]]; then
    compose_source="${service_dir}/dockercompose.yml"
  fi
  [[ -f "$compose_source" ]] || fail "aucun fichier Compose trouvé pour $service"

  first_indent="$(awk '/^[[:space:]]*[A-Za-z0-9_.-]+:/ { match($0, /^[ ]*/); print RLENGTH; exit }' "$compose_source")"
  [[ "$first_indent" == "0" || "$first_indent" == "2" ]] || \
    fail "indentation Compose non prise en charge pour $service"

  explicit_services=0
  if grep -Eq '^services:[[:space:]]*$' "$compose_source"; then
    explicit_services=1
  fi

  printf '\n  # --- %s ---\n' "$service" >> "$compose_tmp"
  if ! awk \
    -v explicit_services="$explicit_services" \
    -v first_indent="$first_indent" \
    -v extras_dir="$extras_dir" '
      BEGIN { mode = "services" }

      /^services:[[:space:]]*$/ {
        if (explicit_services == 1) {
          mode = "services"
          next
        }
      }

      /^(volumes|networks|secrets|configs):([[:space:]]*#.*)?[[:space:]]*$/ {
        mode = $1
        sub(/:.*/, "", mode)
        next
      }

      /^[A-Za-z0-9_.-]+:/ {
        if (explicit_services == 1 || first_indent == 2) {
          print "section Compose globale non prise en charge : " $0 > "/dev/stderr"
          exit 2
        }
      }

      {
        if (mode == "services") {
          if (explicit_services == 0 && first_indent == 0) {
            print "  " $0
          } else {
            print $0
          }
        } else {
          print $0 >> (extras_dir "/" mode)
        }
      }
    ' "$compose_source" >> "$compose_tmp"; then
    fail "format Compose incompatible pour $service"
  fi

  env_example="${service_dir}/.env.example"
  if [[ -f "$env_example" ]]; then
    printf '\n# --- %s ---\n' "$service" >> "$env_tmp"
    cat "$env_example" >> "$env_tmp"
    awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/ { print $1 }' "$env_example" >> "$required_vars"
  fi
done

for section in volumes networks secrets configs; do
  section_file="${extras_dir}/${section}"
  [[ -s "$section_file" ]] || continue

  duplicate_entries="$(awk '/^  [A-Za-z0-9_.-]+:/ { key = $1; sub(/:.*/, "", key); print key }' "$section_file" | sort | uniq -d)"
  [[ -z "$duplicate_entries" ]] || \
    fail "entrées ${section} dupliquées : ${duplicate_entries//$'\n'/, }"

  printf '\n%s:\n' "$section" >> "$compose_tmp"
  cat "$section_file" >> "$compose_tmp"
done

duplicate_vars="$(sort "$required_vars" | uniq -d)"
[[ -z "$duplicate_vars" ]] || fail "variables dupliquées entre services : ${duplicate_vars//$'\n'/, }"

if [[ -f "$ENV_OUTPUT" ]]; then
  env_merged="${tmp_dir}/env-merged"
  cp -- "$ENV_OUTPUT" "$env_merged"
  added_vars=()

  while IFS= read -r variable; do
    [[ -z "$variable" ]] && continue
    if ! grep -Eq "^[[:space:]]*${variable}=" "$ENV_OUTPUT"; then
      grep -E "^${variable}=" "$env_tmp" >> "$env_merged"
      added_vars+=("$variable")
    fi
  done < "$required_vars"

  if (( ${#added_vars[@]} > 0 )); then
    install -m 600 "$env_merged" "$ENV_OUTPUT"
    printf 'Variables ajoutées à %s : %s\n' "$ENV_OUTPUT" "${added_vars[*]}"
  else
    chmod 600 "$ENV_OUTPUT"
  fi
else
  install -m 600 "$env_tmp" "$ENV_OUTPUT"
  printf 'Fichier %s créé avec des valeurs à personnaliser.\n' "$ENV_OUTPUT"
fi

mv -- "$compose_tmp" "$COMPOSE_OUTPUT"

printf 'Fichier Compose généré : %s\n' "$COMPOSE_OUTPUT"
printf 'Avant le déploiement, remplacez toutes les valeurs CHANGE_ME dans %s.\n' "$ENV_OUTPUT"
