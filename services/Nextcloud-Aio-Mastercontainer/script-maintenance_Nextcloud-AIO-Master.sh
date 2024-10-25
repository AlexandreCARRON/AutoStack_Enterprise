#!/bin/bash

# Fonction pour demander l'exécution d'une commande après avoir donné une explication
run_command() {
  local command_desc=$1
  local command_explanation=$2
  local command=$3

  # Afficher l'explication de la commande
  echo "$command_desc :"
  echo "$command_explanation"
  echo ""

  # Demander à l'utilisateur s'il veut exécuter la commande
  read -p "Voulez-vous exécuter la commande ? (y/n) : " choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    echo "Exécution : $command"
    eval "$command"
  else
    echo "Commande ignorée."
  fi
  echo ""
}

# Récupérer l'ID du container ayant l'image "nextcloud/aio-nextcloud:latest"
container_id=$(docker ps -q --filter "ancestor=nextcloud/aio-nextcloud:latest")

# Vérifier si un container avec l'image existe
if [ -z "$container_id" ]; then
  echo "Aucun container avec l'image 'nextcloud/aio-nextcloud:latest' n'a été trouvé."
  exit 1
else
  echo "Container Nextcloud trouvé avec l'ID : $container_id"
  echo ""
fi

# Liste des commandes avec descriptions et explications
commands=(
  "Activation du mode maintenance"
  "Le mode maintenance désactive temporairement l'accès pour éviter les problèmes durant les opérations de maintenance."
  "sudo docker exec -u www-data -it $container_id php occ maintenance:mode --on"
  
  "Vérification de l'intégrité des fichiers"
  "Cette commande vérifie que tous les fichiers de Nextcloud sont intacts et qu'aucun n'a été modifié."
  "sudo docker exec -u www-data -it $container_id php occ integrity:check-core"
  
  "Réparation des incohérences dans la base de données"
  "Cette commande tente de réparer automatiquement les incohérences dans la base de données et d'autres composants."
  "sudo docker exec -u www-data -it $container_id php occ maintenance:repair"
  
  "Conversion de la colonne filecache en BigInt"
  "Cette commande convertit la colonne filecache de la base de données en BigInt, ce qui est important pour les grandes installations."
  "sudo docker exec -u www-data -it $container_id php occ db:convert-filecache-bigint"
  
  "Liste des utilisateurs"
  "Affiche une liste de tous les utilisateurs enregistrés dans Nextcloud."
  "sudo docker exec -u www-data -it $container_id php occ user:list"
  
  "Nettoyage des fichiers inutilisés"
  "Supprime les fichiers temporaires et inutilisés pour libérer de l'espace disque."
  "sudo docker exec -u www-data -it $container_id php occ files:cleanup"
  
  "Scan des fichiers pour mettre à jour les permissions"
  "Cette commande force la mise à jour des droits et des index sur tous les fichiers de Nextcloud."
  "sudo docker exec -u www-data -it $container_id php occ files:scan --all"
  
  "Vérification du statut du serveur"
  "Affiche le statut actuel de l'installation Nextcloud, incluant la version et les paramètres actifs."
  "sudo docker exec -u www-data -it $container_id php occ status"
  
  "Vider le cache OPcache"
  "Cette commande vide le cache OPcache pour s'assurer que les modifications dans les fichiers PHP sont prises en compte immédiatement."
  "sudo docker exec -u www-data -it $container_id php -r 'opcache_reset();'"
  
  "Vérification des applications installées"
  "Affiche la liste des applications Nextcloud installées et leur statut (activées/désactivées)."
  "sudo docker exec -u www-data -it $container_id php occ app:list"
  
  "Désactivation du mode maintenance"
  "Cette commande désactive le mode maintenance pour rendre le service à nouveau accessible aux utilisateurs."
  "sudo docker exec -u www-data -it $container_id php occ maintenance:mode --off"
)

# Exécuter chaque commande après explication et confirmation
for ((i=0; i<${#commands[@]}; i+=3)); do
  run_command "${commands[i]}" "${commands[i+1]}" "${commands[i+2]}"
done
