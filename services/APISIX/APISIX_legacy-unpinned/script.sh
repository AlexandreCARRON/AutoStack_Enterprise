#!/bin/bash

# Installateur POC historique incomplet, conservé uniquement pour référence.
# Ne pas l'utiliser pour un nouveau déploiement : il supprime des ressources Docker
# nommées, fixe les adresses IP et contient une ancienne clé Admin de démonstration.

###############################################################################
# APISIX POC INSTALLER
# Debian 12
# Auteur : Alexandre CARRON
###############################################################################

set -e

# ---------------------------------------------------------------------------
# Fonction d'affichage
# ---------------------------------------------------------------------------
step() {
    echo ""
    echo "================================================================="
    echo "$1"
    echo "================================================================="
}

# ---------------------------------------------------------------------------
# Validation utilisateur
# ---------------------------------------------------------------------------
confirm() {
    read -rp "$1 (Y/n) : " response

    case "$response" in
        [nN]|[nN][oO])
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

# Ces valeurs figées expliquent le fonctionnement du POC mais empêchent sa composition
# sûre avec d'autres stacks ; la variante maintenue utilise Docker Compose à la place.
# APISIX_IP et NGINX_IP sont conservées uniquement pour documenter l'adressage prévu.
APISIX_NETWORK="apisix"
ETCD_IP="172.18.5.10"
# shellcheck disable=SC2034
APISIX_IP="172.18.5.11"
# shellcheck disable=SC2034
NGINX_IP="172.18.5.20"

APISIX_ROOT="$HOME/apisix-poc"

mkdir -p "$APISIX_ROOT"

###############################################################################
# ETAPE 1
###############################################################################

step "Installation de Docker"

if confirm "Installer Docker et les outils nécessaires ?"; then

    sudo apt update

    sudo apt install -y \
        docker.io \
        curl \
        jq

    sudo systemctl enable docker
    sudo systemctl start docker

    sudo usermod -aG docker "$USER"

    echo ""
    echo "Docker installé."
    echo "Une reconnexion de session peut être nécessaire."
fi

###############################################################################
# ETAPE 2
###############################################################################

step "Création du réseau Docker APISIX"

if confirm "Créer le réseau Docker APISIX ?"; then

    # Suppression volontairement destructive héritée du POC d'origine.
    docker network rm "$APISIX_NETWORK" 2>/dev/null || true

    docker network create \
        --driver bridge \
        --subnet=172.18.0.0/16 \
        --ip-range=172.18.5.0/24 \
        --gateway=172.18.5.254 \
        "$APISIX_NETWORK"

    docker network inspect "$APISIX_NETWORK"
fi

###############################################################################
# ETAPE 3
###############################################################################

step "Déploiement ETCD"

if confirm "Déployer ETCD ?"; then

    # Le nom de conteneur global est remplacé de force : autre raison de ne pas exécuter ce POC.
    docker rm -f etcd-server 2>/dev/null || true

    docker pull quay.io/coreos/etcd:v3.5.18

    docker run -d \
        --name etcd-server \
        --network "$APISIX_NETWORK" \
        --ip "$ETCD_IP" \
        -p 2379:2379 \
        -p 2380:2380 \
        quay.io/coreos/etcd:v3.5.18 \
        /usr/local/bin/etcd \
        --name etcd0 \
        --advertise-client-urls http://0.0.0.0:2379 \
        --listen-client-urls http://0.0.0.0:2379

    sleep 5

    curl http://localhost:2379/version || true
fi

###############################################################################
# ETAPE 4
###############################################################################

step "Création configuration APISIX"

if confirm "Créer la configuration APISIX ?"; then

    mkdir -p "$APISIX_ROOT/conf"

    # Cette clé est publique et illustrative ; elle n'est pas un secret de déploiement.
    cat > "$APISIX_ROOT/conf/config.yaml" <<EOF
deployment:
  role: traditional

  admin:
    allow_admin:
      - 0.0.0.0/0

    admin_key:
      -
        name: admin
        key: edd1c9f034335f136f87ad84b625c8f1
        role: admin

  etcd:
    host:
      - "http://${ETCD_IP}:2379"
EOF

    echo "Configuration générée :"
    cat "$APISIX_ROOT/conf/config.yaml"
fi

echo "POC historique incomplet : utilisez ../Apisix_v3.18.0."
