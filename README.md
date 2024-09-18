# Autostack_Enterprise

## Introduction

Bienvenue sur le repo Github du projet AutoStack_Enterprise. 

Ce projet est en cours de développement, et représente une solution flexible pour les startups et autres projets à impact, leur permettant de déployer des infrastructures robustes et évolutives à faible coût. L'objectif est d'offrir une stack clé en main, facilement configurable, afin de permettre aux entreprises de tester rapidement leurs idées et de passer à l'échelle.

Ce dépôt est en évolution constante, je travaille épidosiquement à l'amélioration du code et de la documentation. Toutes les contributions sont les bienvenues, que ce soit sous forme de retour d'expérience, de suggestions ou de propositions d'améliorations.

## État actuel du projet

Bien que fonctionnel sur plusieurs services, le projet est encore en phase de développement. Plusieurs optimisations et bonnes pratiques restent à implémenter. 
Voici un aperçu des tâches à venir :

    Optimisation des services pour un appel à la demande (Terminé)
    Amélioration de la gestion des variables d'environnement (En cours)
    Automatisation du script de configuration pour la machine hôte (À améliorer)
    Amélioration de la gestion des entrypoints
    Nettoyage des fichiers et dossiers inutiles (comme fake.md)
    Rédaction d'une documentation complète et détaillée
    Organisation efficace du backlog pour les fonctionnalités à venir

## Contribution

J'encourage toutes les contributions, qu'elles concernent le code, la documentation ou simplement des retours constructifs. L'objectif est de faire de AutoStack_Enterprise un outil utile pour les entreprises et les développeurs souhaitant accélérer leur processus de déploiement.

## Pré-paramétrage du serveur HOST

/!\ Ce repo est testé sur un ou plusieurs serveur VPS Debian 12, hébergés chez OVH. Quelques petites lignes, nottament au niveau des scripts, peuvent être à changer si vous utilisez un autre hébergeur ou OS Linux

### Pré-paramétrage à la mano (très light)

- Installer git : `sudo apt install git`

### Pré-paramétrage automatisé via script

1. Se logguer sur votre serveur fraîchement installé.
2. Copiez le contenu de ce repo sur votre serveur : <code>sudo git clone https://github.com/AlexandreCARRON/AutoStack_Enterprise.git</code>
3. Rendez-vous dans le dossier nouvellement créé : <code>cd AutoStack_Enterprise</code>
4. Modifiez le fichier .env pour y mettre le nom d'utilisateur et mdp que vous souhaitez : <code>sudo nano .env</code>
5. Rendez exécutable le fichier script.sh : `sudo chmod +x script-conf-server-D12.sh`
6. Exécutez ensuite le script : `sudo ./script-conf-server-D12.sh`

  /!\ ATTENTION /!\ : Votre port SSH de connexion a été modifié selon la variable dans .env !! Si vous ne l'avez pas modifiée, vous pouvez maintenant taper <code>ssh toto@IPouDNS -p 22022</code>

## Déploiement de l'infra

Se rendre dans le dossier git nouvellement copié grace au script : `cd AutoStack_Enterprise`

Afin de générer un fichier docker-compose.yml avec uniquement les services qui vous interessent, executez generator-docker-compose.sh en mettant en argument les noms de dossiers des différents services à déployer : 

Executer avec les bons arguments : <code>sudo ./generate-docker-compose.sh NomService1 NomService2 </code>
Exemple pour deployer rapidement un site web avec odoo : <code>sudo ./generate-docker-compose.sh Nginx-Proxy-Manager Odoo</code>

Vous pouvez maintenant aller éditer le fichier .env généré pour personnaliser les ports et mots de passes : <code>sudo nano .env</code>

Pour le premier déploiement histoire de vérifier que tout se passe bien : 

`sudo docker compose up`

En non verbeux pour pouvoir utiliser le shell ensuite (le `-d` signifie daemon => s'exécute en arrière-plan)

`sudo docker compose up -d`

## Sécurité

### Gestion des mots de passe

/!\ Attention à bien changer les mots de passe et ports dans le fichier généré `docker-compose.yml` ET dans le `odoo.conf` ET dans le .env (à terme plus de mdp dans `docker-compose.yml`, et fichier .dev généré automatiquement en fonction sevices à déployer) !!! /!\

### Gestion des ports

Les ports exposés sont déjà des ports pas communs donc c'est relativement bien. 
Mais ce repo est public, donc des petits malins peuvent peut-être connaître vos ports d'exposition si vous ne les changez pas. 

Pensez à changer tous les ports en 220XX avant de lancer votre infra ;) Et si je l'ai écrit trop tard, faites un `docker-compose down`, éditez le fichier docker-compose.yml, puis relancez. Sorry pour les manips, mais console toi en te disant que c'est le métier qui rentre jeune padawan !

## Commandes utiles

### Liste des containers UP
`sudo docker ps`

### Liste des volumes
`sudo docker ls`

### Copier fichier/dossier depuis container vers host
`sudo docker cp <container_id>:/path/to/file /host/path/to/destination`

### Afficher contenu d'un fichier du container depuis machine hôte
`sudo docker exec <container_id> cat /path/to/file`

### Se connecter au shell à l'intérieur d'un container
`sudo docker exec -it <id_container> bash`

## Licence

Ce contenu est en licence GNU GPLv3, il peut être réutilisé comme bon vous semble, c'est cadeau ! Détails dans le fichier de licence.

Petit glissage discret de fin pour que je puisse bouffer :  https://alexandrecarron.fr ! 

Enjoy !
