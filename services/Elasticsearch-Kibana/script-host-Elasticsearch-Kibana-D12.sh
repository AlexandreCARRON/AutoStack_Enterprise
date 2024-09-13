!#/bin/bash

#Modification pour éviter le problème avec les bootstrap checks d'Elasticsearch. Plus précisément, la limite de mémoire virtuelle vm.max_map_count est trop basse de base sur l'host pour Elasticsearch.
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Appliquer les modifs
sudo sysctl -p
