#!/bin/bash

# ********************************************************************* Charger les variables d'environnement à partir du fichier .env *************************************
if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
else
  echo "Fichier .env introuvable !"
  exit 1
fi

# Vérifier si NEW_PASSWORD et NEW_USER sont définis
if [ -z "$NEW_PASSWORD" ]; then
  echo "NEW_PASSWORD n'est pas défini dans le fichier .env !"
  exit 1
fi

if [ -z "$NEW_USER" ]; then
  echo "NEW_USER n'est pas défini dans le fichier .env !"
  exit 1
fi

# ********************************************************************* Changements MDP et DROITS *************************************
# Changer le mot de passe pour l'utilisateur root
echo "Changement du mots de passe pour l'utilisateurs root"
echo "root:$NEW_PASSWORD" | sudo chpasswd

# Créer le nouvel utilisateur et affecter mot de passe
echo "Création du nouvel utilisateur $NEW_USER..."
sudo useradd -m -s /bin/bash $NEW_USER
echo "Changement du mots de passe pour l'utilisateurs $NEW_USER..."
echo "$NEW_USER:$NEW_PASSWORD" | sudo chpasswd

# Ajouter le nouvel utilisateur aux groupes sudo et docker
sudo usermod -aG sudo $NEW_USER
sudo usermod -aG docker $NEW_USER

# Accorder des privilèges root au nouvel utilisateur
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$NEW_USER

# Désactiver le compte debian
echo "Désactivation du compte debian..."
sudo usermod -L debian

# ********************************************************************* Installation DOCKER *************************************
# Installer Docker Engine
echo "Installation de Docker Engine..."
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajouter le repo aux sources Apt
echo "Ajout du repo aux sources Apt"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# Installation des packages Docker
echo "Installation des packages Docker"
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ********************************************************************* Installation GIT (inutile en principe) *************************************
# Installer Git
echo "Installation de Git..."
sudo apt-get install -y git

# ********************************************************************* Installation FAIL2BAN *************************************
# Installation et configuration de Fail2Ban
echo "Installation de Fail2Ban..."
sudo apt-get install -y fail2ban

# Configuration de Fail2Ban
echo "Configuration de Fail2Ban..."
sudo bash -c 'cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 10m
findtime  = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh

#[http-get-dos]
#enabled = true
#port = http,https
#filter = http-get-dos
#logpath = /var/log/nginx/access.log
#maxretry = 300
#findtime = 300
#bantime = 600

[docker]
enabled = true
port = 2375
EOF'

# Redémarrer Fail2Ban
echo "Redémarrage de Fail2Ban..."
sudo systemctl restart fail2ban

echo "Exécution du script terminée avec succès !"
