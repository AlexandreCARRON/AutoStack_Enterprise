#!/bin/bash

##############################################################################################################################
### MANUEL ###
#Ce fichier permet de générer le fichier docker-compose.yml et .env en appelant les services contenus dans ./services/NOMDUSERVICE
#Il doit être executable sur le serveur. Commande "sudo chmdo +x generate-docker-compose.sh"
#Executer en ajoutant en arguments les noms des dossiers. 
#Exemple : "sudo ./generate-docker-compose.sh Portainer Odoo ServiceX"

###Une fois le fichier généré, personnalisez le .env généré, et vous pouvez executer votre "sudo docker compose up" de manière classique ###

##############################################################################################################################

# Vérifier si au moins un argument est passé
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 service1 service2 ..."
    exit 1
fi

# Commencer à générer le fichier docker-compose.yml
> docker-compose.yml
echo "services:" >> docker-compose.yml

# Boucler sur chaque service fourni en argument
for service in "$@"
do
    service_dir="./services/$service"
    if [ -d "$service_dir" ]; then
        # Inclure le fichier docker-compose.yml du service
        service_compose_file="$service_dir/docker-compose.yml"
        if [ -f "$service_compose_file" ]; then
            # Lire le contenu du fichier docker-compose du service et l'ajouter au fichier principal
            sed 's/^/  /' "$service_compose_file" >> docker-compose.yml
            echo "" >> docker-compose.yml
        else
            echo "Le fichier $service_compose_file n'existe pas bien que le dossier $service_dir ait été trouvé. "
        fi

        # Inclure le fichier .env du service
        service_env_file="$service_dir/.env"
        if [ -f "$service_env_file" ]; then
            echo "" >> .env
            cat "$service_env_file" >> .env
        else
            echo "Le fichier $service_env_file n'existe pas bien que le dossier $service_dir ait été trouvé."
        fi
    else
        echo "Le dossier $service_dir n'existe pas."
    fi
done

echo "Fichier docker-compose.yml généré avec succès !"
