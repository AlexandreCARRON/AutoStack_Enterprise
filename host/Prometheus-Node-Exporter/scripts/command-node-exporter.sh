#!/bin/bash

set -Eeuo pipefail

COMPONENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly COMPONENT_DIR

# Met à jour la liste des paquets disponibles et met à jour les paquets installés
sudo apt update && sudo apt upgrade -y

# Télécharge la version 1.8.2 de Node Exporter depuis le dépôt GitHub
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

# Décompresse l'archive tar.gz téléchargée
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz

# Déplace l'exécutable node_exporter dans le répertoire /usr/local/bin/ pour qu'il soit accessible globalement
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/

# Crée un utilisateur système appelé 'node_exporter' sans shell et sans répertoire home, pour des raisons de sécurité
sudo useradd -rs /bin/false node_exporter

# Copie le service systemd depuis la racine du composant, quel que soit le dossier courant.
sudo install -m 0644 "${COMPONENT_DIR}/service_node-config.txt" /etc/systemd/system/node_exporter.service

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

echo "############################################# Les données Node Exporter sont maintenant disponibles via l'adresse <IP/DNS>:9100/metrics"
