# Projet en cours, Readme à rédiger

## Disclaimer

Bienvenue sur ce méga repo de ouf qui tue sa maman !!

Mouai... C'est en cours de dev !! Ca avance au fur et à mesure, et il y a encore énormément de choses à améliorer !

Pleins de mauvaises pratiques tu trouveras ici jeune padawan (genre des :ro inexistants... mais sais-tu seulement de quoi je parle ?) ! Pour les maîtres Jedi, j'ai soif d'apprentissage, donc n'hésite pas à commenter les fichiers pour qu'on puisse améliorer ça ensemble ! Dans la bienveillance tu agiras, en toute humilité je réagirai !!

Voici à date les améliorations à venir que j'envisage à court terme : 
- Scinder les services et les appeler à la demande
- Améliorer la gestion des variables
- Script d'automatisation config machine hôte
- Meilleur gestion des entrypoint
- Suppression des dossiers et fichiers (fake.md notamment) inutiles
- Pondre une fucking doc digne de ce nom
- Passer par les bons tuyaux pour faire mon backlog !!!

Je suis preneur de toute aide autour de ce projet. En gros, l'idée est de faire une stack facile à mettre en place pour qu'on puisse aider les startups de notre Startup Nation (Youhou !), ou autres projets à impact, à avoir des outils efficients et peu coûteux pour qu'ils puissent tester leurs idées et scaler rapidement (je me fais presque peur avec mon vocabulaire !). Bref ! En vrai, je m'amuse à faire un projet qui, je l'espère, servira à d'autres pour gagner du temps sur leurs déploiements sans trop dépenser d'argent !

Voilà fin du disclaimer : Pour ton infra, je m'occupe de rien, tu t'occupes de tout, et je ne saurais être tenu responsable d'une mauvaise utilisation ou d'un bug lié à ce repo !

Bisous Merci Bisous !

## Pré-paramétrage du serveur host

### Pré-paramétrage à la mano (très light)

- Installer docker engine : [Lien vers la doc](https://docs.docker.com/engine/install/)
- Installer git : `sudo apt install git`

### Pré-paramétrage automatisé via script

1. Se logguer sur votre serveur fraîchement installé.
2. Créer les fichiers suivants sur le serveur host et copier-coller le contenu des fichiers depuis le repo Git. 

- Copiez le contenu trouvé dans ./script-conf-server-D12.sh dans ce fichier : `sudo nano script.sh`
- Copiez les lignes relatives à CONFIG SERVEUR du fichier ./.env dans ce fichier : `sudo nano .env`

3. Rendez exécutable le fichier script.sh : `sudo chmod +x script.sh`
4. Exécutez ensuite le script : `./script.sh`

#### VOILA ! /!\ NE PAS OUBLIER DE SUPPRIMER LES 2 FICHIERS CRÉÉS POUR UN MINIMUM DE SÉCURITÉ /!\

## Déploiement de l'infra

Importer le repo : `sudo git clone https://github.com/AlexandreCARRON/Odoo-v17_Automatic-deployement-services.git`

Se rendre dans le dossier copié : `cellelatulatrouvetoutseulnonmais!`

Pour le premier déploiement histoire de vérifier que tout se passe bien : 

`sudo docker-compose up`

En non verbeux pour pouvoir utiliser le shell ensuite (le `-d` signifie daemon => s'exécute en arrière-plan)

`sudo docker-compose up -d`

## Sécurité

### Gestion des mots de passe

/!\ Attention à bien changer les mots de passe dans le fichier `docker-compose.yml` ET dans le `odoo.conf` ET dans le .env (à terme plus de mdp dans `docker-compose.yml`) !!! /!\

### Gestion des ports

Les ports exposés sont déjà des ports pas communs donc c'est relativement bien. 
Mais ce repo est public, donc des petits malins peuvent peut-être connaître vos ports d'exposition si vous ne les changez pas. 

Pensez à changer tous les ports en 220XX avant de lancer votre infra ;) Et si je l'ai écrit trop tard, faites un `docker-compose down`, éditez le fichier docker-compose.yml, puis relancez. Sorry pour les manips, mais console toi en te disant que c'est le métier qui rentre jeune padawan !

## Commandes utiles

En principe, avant de taper les commandes, vous avez mis votre utilisateur dans les sudoers, donc le sudo en début de commande n'est pas nécessaire...

### Liste des containers UP
`sudo docker ps`

### Liste des volumes
`sudo docker ls`

### Copier fichier/dossier depuis container vers host
`sudo docker cp <container_id>:/path/to/file /host/path/to/destination`

### Afficher contenu d'un fichier du container depuis machine hôte
`sudo docker exec <container_id> cat /path/to/file`

## Licence

Ce contenu est en licence GNU GPLv3, il peut être réutilisé comme bon vous semble, c'est cadeau ! Détails dans le fichier de licence.

Petit glissage discret de fin pour que je puisse bouffer :  https://alexandrecarron.fr ! 

Enjoy !
