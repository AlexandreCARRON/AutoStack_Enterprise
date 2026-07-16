# Autostack_Enterprise

## Introduction

Bienvenue sur le repo Github du projet AutoStack_Enterprise.

Ce projet est en cours de développement, et représente une solution flexible pour les startups et autres projets à impact, leur permettant de déployer des infrastructures robustes et évolutives à faible coût. L'objectif est d'offrir une stack clé en main, facilement configurable, afin de permettre aux entreprises de tester rapidement leurs idées et de passer à l'échelle.

Ce dépôt est en évolution constante, je travaille épidosiquement à l'amélioration du code et de la documentation. Toutes les contributions sont les bienvenues, que ce soit sous forme de retour d'expérience, de suggestions ou de propositions d'améliorations.

## État actuel du projet

Bien que fonctionnel sur plusieurs services, le projet est encore en phase de développement. Plusieurs optimisations et bonnes pratiques restent à implémenter.
Voici un aperçu des tâches à venir :

- Optimisation des services pour un appel à la demande (Terminé)
- Amélioration de la gestion des variables d'environnement (En cours)
- Automatisation du script de configuration pour la machine hôte (À améliorer)
- Amélioration de la gestion des entrypoints
- Nettoyage des fichiers et dossiers inutiles (comme fake.md)
- Rédaction d'une documentation complète et détaillée
- Organisation efficace du backlog pour les fonctionnalités à venir

## Contribution

J'encourage toutes les contributions, qu'elles concernent le code, la documentation ou simplement des retours constructifs. L'objectif est de faire de AutoStack_Enterprise un outil utile pour les entreprises et les développeurs souhaitant accélérer leur processus de déploiement.

## Pré-paramétrage du serveur HOST

/!\ Ce repo est testé sur un ou plusieurs serveur VPS Debian 12, hébergés chez OVH. Quelques petites lignes, nottament au niveau des scripts, peuvent être à changer si vous utilisez un autre hébergeur ou OS Linux

### Pré-paramétrage à la mano (très light)

- Installer git : `sudo apt install git`

### Pré-paramétrage automatisé via script

1. Se logguer sur votre serveur fraîchement installé.
2. Copiez le contenu de ce repo sur votre serveur : `git clone https://github.com/AlexandreCARRON/AutoStack_Enterprise.git`.
3. Rendez-vous dans le dossier nouvellement créé : `cd AutoStack_Enterprise`.
4. Créez votre configuration locale : `cp .env.example .env`.
5. Remplacez toutes les valeurs `CHANGE_ME` et adaptez l'utilisateur ainsi que le port SSH : `nano .env`.
6. Rendez le script exécutable : `chmod +x script-conf-server-D12.sh`.
7. Exécutez ensuite le script : `sudo ./script-conf-server-D12.sh`.

> **Attention :** le script modifie le port SSH selon `NEW_PORT_SSH`. Gardez une session ouverte jusqu'à avoir vérifié une nouvelle connexion.

## Déploiement de l'infra

Se rendre dans le dossier Git nouvellement copié : `cd AutoStack_Enterprise`.

Le générateur assemble uniquement les services demandés. Il crée un fichier `.env` privé lors de la première exécution et y ajoute ensuite les variables manquantes sans remplacer les valeurs existantes.

```bash
./generate-docker-compose.sh NomService1 NomService2
```

Exemple pour déployer Nginx Proxy Manager et Odoo :

```bash
./generate-docker-compose.sh Nginx-Proxy-Manager Odoo
```

Le générateur refuse d'écraser un fichier `docker-compose.yml` existant. Pour le régénérer volontairement :

```bash
FORCE=1 ./generate-docker-compose.sh Nginx-Proxy-Manager Odoo
```

Avant le déploiement, remplacez toutes les valeurs `CHANGE_ME` dans `.env`, puis validez la configuration :

```bash
docker compose config --quiet
docker compose up
```

Pour lancer la stack en arrière-plan :

```bash
docker compose up -d
```

## Sécurité

### Gestion des mots de passe

- Ne committez jamais `.env`, une clé privée ou un fichier `secret_*.txt`.
- Remplacez toutes les valeurs `CHANGE_ME` avant le premier démarrage.
- Traitez `volumes/Odoo/etc/odoo.conf` et les fichiers de configuration sous `volumes/` comme des données sensibles.
- Préférez les secrets Docker ou des fichiers montés en lecture seule pour les identifiants de production.

N8N utilise des volumes Docker nommés (`n8n_data` et `n8n_db_data`). Avant de migrer une installation existante basée sur les anciens dossiers `volumes/n8n`, sauvegardez puis transférez explicitement les données.

### Gestion des ports

Un port non standard réduit seulement le bruit des scans automatisés ; ce n'est pas une mesure de sécurité. Limitez l'exposition avec le pare-feu, placez les interfaces d'administration derrière un reverse proxy HTTPS et n'ouvrez que les ports nécessaires.

## Commandes utiles

### Liste des containers UP

`sudo docker ps`

### Liste des volumes

`sudo docker volume ls`

### Copier fichier/dossier depuis container vers host

`sudo docker cp <container_id>:/path/to/file /host/path/to/destination`

### Afficher contenu d'un fichier du container depuis machine hôte

`sudo docker exec <container_id> cat /path/to/file`

### Se connecter au shell à l'intérieur d'un container

`sudo docker exec -it <id_container> bash`

## Licence

Ce contenu est en licence GNU GPLv3, il peut être réutilisé comme bon vous semble, c'est cadeau ! Détails dans le fichier de licence.

Petit glissage discret de fin pour que je puisse bouffer : <https://alexandrecarron.fr> !

Enjoy !
