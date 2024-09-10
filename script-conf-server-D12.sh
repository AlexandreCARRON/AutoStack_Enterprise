#!/bin/bash

# ********************************************************************* Charger les variables d'environnement à partir du fichier .env *************************************
if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
else
  echo "##################### Fichier .env introuvable !"
  exit 1
fi

# Vérifier si NEW_PASSWORD et NEW_USER sont définis
if [ -z "$NEW_PASSWORD" ]; then
  echo "#################### NEW_PASSWORD n'est pas défini dans le fichier .env !"
  exit 1
fi

if [ -z "$NEW_USER" ]; then
  echo "################### NEW_USER n'est pas défini dans le fichier .env !"
  exit 1
fi

# ********************************************************************* Installation DOCKER *************************************
# Installer Docker Engine
echo "######### Installation de Docker Engine..."
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajouter le repo aux sources Apt
echo "######### Ajout du repo aux sources Apt"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# Installation des packages Docker
echo "######### Installation des packages Docker : docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ********************************************************************* Installation GIT (inutile en principe) *************************************
# Installer Git
echo "######### Installation de Git..."
sudo apt-get install -y git

# ********************************************************************* Installation RSYNC *************************************
# Installer Rsync
echo "######### Installation de Rsync..."
sudo apt-get install -y rsync

# ********************************************************************* Installation btop *************************************
# Installer btop
echo "######### Installation de btop, pour visualiser l'utilisation des ressources de votre hote directement dans le shell..."
sudo apt-get install -y btop

# ********************************************************************* Installation FAIL2BAN *************************************
# Installation et configuration de Fail2Ban
echo "######### Installation de Fail2Ban..."
sudo apt-get install -y fail2ban

# Configuration de Fail2Ban via le fichier préparamétré disponible dans le repo
echo "######### Configuration de Fail2Ban..."
sudo cp ./host/fail2ban/jail.local /etc/fail2ban/jail.local
sudo service fail2ban restart

echo "######### Les paramètre spécifiques de surveillance de protocols ont été implémentés et le service a été redémarré."

# Vérifier la configuration de Fail2Ban
echo "### Vérification de la configuration de Fail2Ban..."
sudo fail2ban-client -d
if [ $? -ne 0 ]; then
  echo "######################## Erreur dans la configuration de Fail2Ban. Veuillez vérifier le fichier /etc/fail2ban/jail.local."
  exit 1
fi

# Redémarrer Fail2Ban
echo "######### Redémarrage de Fail2Ban..."
sudo systemctl restart fail2ban

# Vérifier l'état du service Fail2Ban
echo "######### Vérification de l'état du service Fail2ban après redémarrage"
sudo systemctl status fail2ban

# ********************************************************************* Installation de Prometheus Node Exporter *************************************
# Télécharge et décompresse la version 1.8.2 de Node Exporter depuis le dépôt GitHub
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz

# Déplace l'exécutable node_exporter dans le répertoire /usr/local/bin/ pour qu'il soit accessible globalement
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/

# Crée un utilisateur système appelé 'node_exporter' sans shell et sans répertoire home, pour des raisons de sécurité
sudo useradd -rs /bin/false node_exporter

# Copie le fichier de configuration service_node-config.txt dans le fichier de service systemd pour Node Exporter
sudo cat ./host/Prometheus-Node-Exporter/service_node-config.txt > /etc/systemd/system/node_exporter.service

# Recharge les fichiers de configuration systemd pour prendre en compte le nouveau service
sudo systemctl daemon-reload

# Démarre le service Node Exporter
sudo systemctl start node_exporter

# Active le service Node Exporter pour qu'il démarre automatiquement au démarrage de la machine
sudo systemctl enable node_exporter

# Vérifie le statut du service Node Exporter pour s'assurer qu'il fonctionne correctement
sudo systemctl status node_exporter

# (Optionnel) Ouvre le port 9100 sur le firewall pour autoriser les connexions TCP à Node Exporter (commenté ici)
# sudo ufw allow 9100/tcp

# Supprime l'archive téléchargée
rm node_exporter-1.8.2.linux-amd64.tar.gz

# Supprime le dossier extrait
rm -rf node_exporter-1.8.2.linux-amd64

echo "############################################# Les données Node Exporter sont maintenant disponibles via l'adresse <IP/DNS>:9100/metrics"

# ********************************************************************* Changements MDP et DROITS *************************************
# Changer le mot de passe pour l'utilisateur root
echo "######### Changement du mots de passe pour l'utilisateurs root"
echo "root:$NEW_PASSWORD" | sudo chpasswd

# Créer le nouvel utilisateur et affecter mot de passe
echo "######### Création du nouvel utilisateur $NEW_USER..."
sudo useradd -m -s /bin/bash $NEW_USER
echo "### Changement du mots de passe pour l'utilisateurs $NEW_USER..."
echo "$NEW_USER:$NEW_PASSWORD" | sudo chpasswd

# Ajouter le nouvel utilisateur aux groupes sudo et docker (pour docker permet d'éviter à tapper 'sudo' avant la commande 'docker ps' par ex.
echo "######### Ajout du nouvel utilisateur aux groupes sudo et docker"
sudo usermod -aG sudo $NEW_USER
sudo usermod -aG docker $NEW_USER

# Eviter d'avoir à tapper le mot de passe lorsque le nouvel utilisateur utilise 'sudo'
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$NEW_USER

# Autoriser l'accès en lecture au dossier des volumes persistants docker
#sudo chmod -R g+r /var/lib/docker/volumes   # NON FONCTIONNEL et #attention autorise des groupes entiers

# Remplacer le contenu du .bashrc du nouvel utilisateur
echo "######### Personnalisation .bashrc pour le nouvel utilisateur"
if [ -f ./host/.bashrc ]; then
  sudo cp ./host/.bashrc /home/$NEW_USER/.bashrc
  sudo chown $NEW_USER:$NEW_USER /home/$NEW_USER/.bashrc
  echo "### Fichier .bashrc copié dans /home/$NEW_USER/.bashrc"
else
  echo "################### Fichier .bashrc introuvable dans ./host"
fi

# Désactiver le compte debian
echo "######### Désactivation du compte debian..."
sudo usermod -L debian

# ********************************************************************* Changement du port SSH *************************************

echo "######### Changement du port SSH pour accéder à la machine"

# Fichier de configuration SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Sauvegarder le fichier de configuration actuel
sudo cp $SSHD_CONFIG $SSHD_CONFIG.bak

# Modifier ou ajouter la ligne Port dans le fichier sshd_config
if sudo grep -q "^Port " $SSHD_CONFIG; then
    # Si une ligne Port existe déjà, la remplacer par la nouvelle
    sudo sed -i "s/^Port .*/Port $NEW_PORT_SSH/" $SSHD_CONFIG
else
    # Si aucune ligne Port n'existe, ajouter la nouvelle ligne à la fin du fichier
     echo "Port $NEW_PORT_SSH" | sudo tee -a $SSHD_CONFIG
fi

# Redémarrer le service SSH pour appliquer les modifications
sudo systemctl restart sshd

echo "######### Le port SSH a été changé en $NEW_PORT_SSH et le service SSH a été redémarré. A la prochaine connexion, il faudra rajouter a la fin de votre commande "-p $NEW_PORT_SSH" !!"

# ********************************************************************* Avertissement et redémarrage du système *************************************

echo "######### Fin de l'éxécution du script de paramétrage automatique #########"
echo "######### ATTENTION: LE SERVEUR VAS MAINTENANT SUBIR UN REBOOT. #########"
echo "Assurez-vous de bien connaître le nom de votre nouvel utilisateur et son mot de passe, car l'utilisateur via lequel vous êtes actuellement connecté a été désactivé"

read -p "=> USER - Voulez-vous afficher le nom du nouvel utilisateur que vous venez de créer ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "User : '$NEW_USER'"
else
    echo "##########"
fi

read -p "=> PASSWD - Voulez-vous afficher le mot de passe du nouvel utilisateur que vous venez de créer ? (y/N) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" ]]; then
    echo "Passwd : '$NEW_PASSWORD'"
else
    echo "##########"
fi

read -p "=> REBOOT - Etes-vous ok pour redémarrer le serveur maintenant ? (Y/n) " response
response=${response,,} # Convertir en minuscule

if [[ "$response" == "y" || -z "$response" ]]; then
    echo "###### Suppression de l'ensemble des fichiers contenus dans /home/debian/[repo-précédement-chargé]"
    sudo rm -rf /home/debian/AutoStack_Enterprise
    echo "###### Copie du repo vierge vers le nouvel utilisateur"
    cd /home/$NEW_USER
    sudo git clone https://github.com/AlexandreCARRON/AutoStack_Enterprise.git
    sudo chmod +x /home/$NEW_USER/AutoStack_Enterprise/generate-docker-compose.sh
    echo "###### Redémarrage du système..."
    sudo reboot now
else
    echo "#################### Redémarrage annulé. Vous pouvez redémarrer manuellement plus tard. ################"
    echo "#################### ATTENTION : votre fichier .env contenu dans /home/debian/.env n'a pas été supprimé, vos informations utilisateur et mdp sont donc disponibles en clair ! Pensez à le supprimer ! ################"

fi
