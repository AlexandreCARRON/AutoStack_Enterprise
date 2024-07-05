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
echo "### Changement du mots de passe pour l'utilisateurs root"
echo "root:$NEW_PASSWORD" | sudo chpasswd

# Créer le nouvel utilisateur et affecter mot de passe
echo "### Création du nouvel utilisateur $NEW_USER..."
sudo useradd -m -s /bin/bash $NEW_USER
echo "### Changement du mots de passe pour l'utilisateurs $NEW_USER..."
echo "$NEW_USER:$NEW_PASSWORD" | sudo chpasswd

# Ajouter le nouvel utilisateur aux groupes sudo et docker
sudo usermod -aG sudo $NEW_USER
sudo usermod -aG docker $NEW_USER

# Accorder des privilèges root au nouvel utilisateur
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$NEW_USER

# Remplacer le contenu du .bashrc du nouvel utilisateur
if [ -f ./host/.bashrc ]; then
  sudo cp ./host/.bashrc /home/$NEW_USER/.bashrc
  sudo chown $NEW_USER:$NEW_USER /home/$NEW_USER/.bashrc
  echo "### Fichier .bashrc copié dans /home/$NEW_USER/.bashrc"
else
  echo "########## Fichier .bashrc introuvable dans ./host"
fi

# Désactiver le compte debian
echo "### Désactivation du compte debian..."
sudo usermod -L debian

# ********************************************************************* Installation DOCKER *************************************
# Installer Docker Engine
echo "### Installation de Docker Engine..."
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajouter le repo aux sources Apt
echo "### Ajout du repo aux sources Apt"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# Installation des packages Docker
echo "### Installation des packages Docker"
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ********************************************************************* Installation GIT (inutile en principe) *************************************
# Installer Git
echo "### Installation de Git..."
sudo apt-get install -y git

# ********************************************************************* Installation FAIL2BAN *************************************
# Installation et configuration de Fail2Ban
echo "### Installation de Fail2Ban..."
sudo apt-get install -y fail2ban

# Configuration de Fail2Ban via le fichier préparamétré disponible dans le repo
echo "### Configuration de Fail2Ban..."
sudo cp ./host/fail2ban/jail.local /etc/fail2ban/jail.local

echo "### Les paramètre spécifiques de surveillance de protocols ont été implémentés."

# Vérifier la configuration de Fail2Ban
echo "### Vérification de la configuration de Fail2Ban..."
sudo fail2ban-client -d
if [ $? -ne 0 ]; then
  echo "##################### Erreur dans la configuration de Fail2Ban. Veuillez vérifier le fichier /etc/fail2ban/jail.local."
  exit 1
fi

# Redémarrer Fail2Ban
echo "### Redémarrage de Fail2Ban..."
sudo systemctl restart fail2ban

# Vérifier l'état du service Fail2Ban
echo "### Vérification de l'état du service Fail2ban après redémarrage"
sudo systemctl status fail2ban

# Avertissement et redémarrage du système

echo "######### Fin de l'éxécution du script de paramétrage automatique #########"
echo "######### ATTENTION: LE SERVEUR VAS MAINTENANT SUBIR UN REBOOT. #########"
echo "Assurez-vous de bien connaître le nom de votre nouvel utilisateur et son mot de passe, car l'utilisateur via lequel vous êtes actuellement connecté a été désactivé"

read -p "USER - Voulez-vous afficher le nom du nouvel utilisateur que vous venez de créer ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "User : '$NEW_USER'"
else
    echo "##########"
fi

read -p "PASSWD - Voulez-vous afficher le mot de passe du nouvel utilisateur que vous venez de créer ? (y/N) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" ]]; then
    echo "Passwd : '$NEW_PASSWORD'"
else
    echo "##########"
fi

read -p "REBOOT - Etes-vous ok pour redémarrer le serveur maintenant ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "Redémarrage du système..."
    sudo reboot now
else
    echo "############## Redémarrage annulé. Vous pouvez redémarrer manuellement plus tard. ################"
