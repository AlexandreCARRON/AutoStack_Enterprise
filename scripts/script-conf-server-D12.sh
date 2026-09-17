#!/usr/bin/env bash

# Arrêter le script à la première erreur et détecter les erreurs dans les pipelines.
set -Eeuo pipefail

# Couleurs ANSI, désactivées hors terminal ou si NO_COLOR est défini.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  YELLOW=$'\033[0;33m'
  RESET=$'\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  RESET=''
fi

info() { printf '%s[INFO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
ok()   { printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[ATTENTION]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s[ERREUR]%s %s\n' "$RED" "$RESET" "$*" >&2; }

# Afficher en rouge la commande et la ligne à l'origine d'une erreur non gérée.
trap 'rc=$?; fail "Échec ligne $LINENO : $BASH_COMMAND (code $rc)"; exit "$rc"' ERR


REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
cd "$REPO_DIR" || exit 1

# ********************************************************************* Charger les variables d'environnement à partir du fichier .env *************************************
if [ -f "${REPO_DIR}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${REPO_DIR}/.env"
  set +a
  ok "Fichier .env chargé."
else
  fail "Fichier .env introuvable."
  exit 1
fi

# Vérifier si NEW_PASSWORD et NEW_USER sont définis
if [ -z "${NEW_PASSWORD:-}" ]; then
  fail "NEW_PASSWORD n'est pas défini dans le fichier .env."
  exit 1
fi

if [ -z "${NEW_USER:-}" ]; then
  fail "NEW_USER n'est pas défini dans le fichier .env."
  exit 1
fi

if [ -z "${NEW_PORT_SSH:-}" ]; then
  fail "NEW_PORT_SSH n'est pas défini dans le fichier .env."
  exit 1
fi

if [[ ! "$NEW_PORT_SSH" =~ ^[0-9]+$ ]]; then
  fail "NEW_PORT_SSH doit être un numéro de port entre 1 et 65535."
  exit 1
fi

NEW_PORT_SSH_DEC=$((10#$NEW_PORT_SSH))
if (( NEW_PORT_SSH_DEC < 1 || NEW_PORT_SSH_DEC > 65535 )); then
  fail "NEW_PORT_SSH doit être un numéro de port entre 1 et 65535."
  exit 1
fi
unset NEW_PORT_SSH_DEC
ok "Variables requises vérifiées."

# ********************************************************************* Installation DOCKER *************************************
# Installer Docker Engine
echo "######### Installation de Docker Engine..."
sudo apt-get update
ok "Index des paquets APT actualisé."
sudo apt-get install -y ca-certificates curl
ok "Dépendances Docker installées."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajouter le repo aux sources Apt
echo "######### Ajout du repo aux sources Apt"
# shellcheck disable=SC1091
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
ok "Sources APT actualisées."

# Installation des packages Docker
echo "######### Installation des packages Docker : docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
ok "Docker Engine et ses composants installés."

# ********************************************************************* Installation GIT (inutile en principe) *************************************
# Installer Git
echo "######### Installation de Git..."
sudo apt-get install -y git
ok "Git installé."

# ********************************************************************* Installation RSYNC *************************************
# Installer Rsync
echo "######### Installation de Rsync..."
sudo apt-get install -y rsync
ok "Rsync installé."

# ********************************************************************* Installation btop *************************************
# Installer btop
echo "######### Installation de btop, pour visualiser l'utilisation des ressources de votre hote directement dans le shell..."
sudo apt-get install -y btop
ok "btop installé."

# ********************************************************************* Installation tree *************************************
# Installer tree
echo "######### Installation de btop, pour visualiser l'arborescende de vos dossiers directement dans le shell..."
sudo apt-get install -y tree
ok "tree installé."

# ********************************************************************* Installation FAIL2BAN *************************************
# Installation et configuration de Fail2Ban
echo "######### Installation de Fail2Ban..."
sudo apt-get install -y fail2ban
ok "Fail2Ban installé."

# Configuration de Fail2Ban via le fichier préparamétré disponible dans le repo
echo "######### Configuration de Fail2Ban..."
sudo cp ./host/fail2ban/jail.local /etc/fail2ban/jail.local
sudo service fail2ban restart

echo "######### Les paramètre spécifiques de surveillance de protocols ont été implémentés et le service a été redémarré."

# Vérifier la configuration de Fail2Ban
echo "### Vérification de la configuration de Fail2Ban..."
if ! sudo fail2ban-client -d; then
  fail "Configuration Fail2Ban invalide. Vérifie le fichier /etc/fail2ban/jail.local."
  exit 1
fi
ok "Configuration Fail2Ban vérifiée."

# Redémarrer Fail2Ban
echo "######### Redémarrage de Fail2Ban..."
sudo systemctl restart fail2ban

# Vérifier l'état du service Fail2Ban
echo "######### Vérification de l'état du service Fail2ban après redémarrage"
sudo systemctl status fail2ban
ok "Service Fail2Ban actif."

# ********************************************************************* Installation de Prometheus Node Exporter *************************************
# Télécharge et décompresse la version 1.8.2 de Node Exporter depuis le dépôt GitHub
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz

# Déplace l'exécutable node_exporter dans le répertoire /usr/local/bin/ pour qu'il soit accessible globalement
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/

# Crée un utilisateur système appelé 'node_exporter' sans shell et sans répertoire home, pour des raisons de sécurité
sudo useradd -rs /bin/false node_exporter

# Copie le fichier de configuration service_node-config.txt dans le fichier de service systemd pour Node Exporter
sudo install -m 0644 ./host/Prometheus-Node-Exporter/service_node-config.txt /etc/systemd/system/node_exporter.service

# Recharge les fichiers de configuration systemd pour prendre en compte le nouveau service
sudo systemctl daemon-reload

# Démarre le service Node Exporter
sudo systemctl start node_exporter

# Active le service Node Exporter pour qu'il démarre automatiquement au démarrage de la machine
sudo systemctl enable node_exporter

# Vérifie le statut du service Node Exporter pour s'assurer qu'il fonctionne correctement
sudo systemctl status node_exporter
ok "Service Node Exporter actif."

# (Optionnel) Ouvre le port 9100 sur le firewall pour autoriser les connexions TCP à Node Exporter (commenté ici)
# sudo ufw allow 9100/tcp

# Supprime l'archive téléchargée
rm node_exporter-1.8.2.linux-amd64.tar.gz

# Supprime le dossier extrait
rm -rf node_exporter-1.8.2.linux-amd64
ok "Installation de Node Exporter terminée."

echo "############################################# Les données Node Exporter sont maintenant disponibles via l'adresse <IP/DNS>:9100/metrics"

# ********************************************************************* Changements MDP et DROITS *************************************
# Changer le mot de passe pour l'utilisateur root
echo "######### Changement du mots de passe pour l'utilisateurs root"
echo "root:$NEW_PASSWORD" | sudo chpasswd
ok "Mot de passe root modifié."

# Créer le nouvel utilisateur et affecter mot de passe
echo "######### Création du nouvel utilisateur $NEW_USER..."
sudo useradd -m -s /bin/bash "$NEW_USER"
echo "### Changement du mots de passe pour l'utilisateurs $NEW_USER..."
echo "$NEW_USER:$NEW_PASSWORD" | sudo chpasswd

# Ajouter le nouvel utilisateur aux groupes sudo et docker (pour docker permet d'éviter à tapper 'sudo' avant la commande 'docker ps' par ex.
echo "######### Ajout du nouvel utilisateur aux groupes sudo et docker"
sudo usermod -aG sudo "$NEW_USER"
sudo usermod -aG docker "$NEW_USER"
ok "Utilisateur $NEW_USER créé et ajouté aux groupes sudo et docker."

# Eviter d'avoir à tapper le mot de passe lorsque le nouvel utilisateur utilise 'sudo'
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/${NEW_USER}"
sudo chmod 0440 "/etc/sudoers.d/${NEW_USER}"
ok "Configuration sudo sans mot de passe installée pour $NEW_USER."

# Autoriser l'accès en lecture au dossier des volumes persistants docker
#sudo chmod -R g+r /var/lib/docker/volumes   # NON FONCTIONNEL et #attention autorise des groupes entiers

# Remplacer le contenu du .bashrc du nouvel utilisateur
echo "######### Personnalisation .bashrc pour le nouvel utilisateur"
if [ -f ./host/.bashrc ]; then
  sudo cp ./host/.bashrc "/home/${NEW_USER}/.bashrc"
  sudo chown "$NEW_USER:$NEW_USER" "/home/${NEW_USER}/.bashrc"
  ok "Fichier .bashrc installé pour $NEW_USER."
else
  warn "Fichier ./host/.bashrc absent; personnalisation ignorée."
fi

# Désactiver le compte debian
echo "######### Désactivation du compte debian..."
sudo usermod -L debian
ok "Compte debian désactivé."

# ********************************************************************* Changement du port SSH *************************************

echo "######### Changement du port SSH pour accéder à la machine"

# Fichier de configuration SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Sauvegarder le fichier de configuration actuel
sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# Modifier ou ajouter la ligne Port dans le fichier sshd_config
if sudo grep -q "^Port " "$SSHD_CONFIG"; then
    # Si une ligne Port existe déjà, la remplacer par la nouvelle
    sudo sed -i "s/^Port .*/Port $NEW_PORT_SSH/" "$SSHD_CONFIG"
else
    # Si aucune ligne Port n'existe, ajouter la nouvelle ligne à la fin du fichier
     echo "Port $NEW_PORT_SSH" | sudo tee -a "$SSHD_CONFIG"
fi

# Redémarrer le service SSH pour appliquer les modifications
sudo systemctl restart sshd

ok "Port SSH changé vers $NEW_PORT_SSH et service redémarré. Ajoute '-p $NEW_PORT_SSH' à la prochaine connexion."

# ********************************************************************* Avertissement et redémarrage du système *************************************

ok "Fin de l'exécution du script de paramétrage automatique."
warn "Le serveur va redémarrer si tu confirmes."
warn "Assure-toi de connaître le nom du nouvel utilisateur et son mot de passe : le compte actuel a été désactivé."

read -r -p "=> USER - Voulez-vous afficher le nom du nouvel utilisateur que vous venez de créer ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "User : '$NEW_USER'"
else
    echo "##########"
fi

read -r -p "=> PASSWD - Voulez-vous afficher le mot de passe du nouvel utilisateur que vous venez de créer ? (y/N) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" ]]; then
    echo "Passwd : '$NEW_PASSWORD'"
else
    echo "##########"
fi

read -r -p "=> REBOOT - Etes-vous ok pour redémarrer le serveur maintenant ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "###### Suppression de l'ensemble des fichiers contenus dans /home/debian/[repo-précédement-chargé]"
    sudo rm -rf /home/debian/AutoStack_Enterprise
    echo "###### Copie du repo vierge vers le nouvel utilisateur"
    cd "/home/${NEW_USER}" || exit 1
    sudo git clone https://github.com/AlexandreCARRON/AutoStack_Enterprise.git
    ok "Dépôt cloné sous /home/$NEW_USER."
    sudo chmod +x "/home/${NEW_USER}/AutoStack_Enterprise/scripts/generate-docker-compose.sh"
    ok "Droits d'exécution du script de génération configurés."
    info "Redémarrage du système..."
    sudo reboot now
else
    warn "Redémarrage annulé. Tu pourras redémarrer manuellement plus tard."
    warn "Le fichier /home/debian/.env n'a pas été supprimé et contient encore des informations sensibles; supprime-le."

fi
