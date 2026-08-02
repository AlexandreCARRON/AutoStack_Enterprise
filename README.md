---
id: autostack.readme
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["docs/README.md", "VERSIONS.md"]
---

# AutoStack Enterprise

## Introduction

AutoStack Enterprise fournit un catalogue de services Docker Compose versionnés et un générateur qui assemble uniquement les briques demandées.

Le projet vise les startups et les projets à impact qui souhaitent tester une infrastructure configurable avant de passer à l'échelle. Les configurations proposées restent des références à adapter et à sécuriser selon le contexte de déploiement.

Le dépôt évolue par pull requests vérifiées. Les contributions peuvent prendre la forme de retours d'expérience, de corrections ou de propositions ciblées.

## État actuel du projet

Bien que fonctionnel sur plusieurs services, le projet est encore en phase de développement. Plusieurs optimisations et bonnes pratiques restent à implémenter.
Voici un aperçu des tâches à venir :

- Optimisation des services pour un appel à la demande (Terminé)
- Amélioration de la gestion des variables d'environnement (En cours)
- Automatisation du script de configuration pour la machine hôte (À améliorer)
- Amélioration de la gestion des entrypoints
- Nettoyage des fichiers et dossiers inutiles (comme fake.md)
- Enrichissement progressif de la documentation opérationnelle
- Organisation efficace du backlog pour les fonctionnalités à venir

## Contribution

Les contributions concernant le code, la documentation et les retours constructifs sont bienvenues. Consultez le [guide de contribution](CONTRIBUTING.md) avant de proposer un changement.

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

Le générateur assemble uniquement les services demandés. Il crée un fichier `.env` privé lors de la première exécution et y ajoute ensuite les variables manquantes sans remplacer les valeurs existantes. Chaque dossier de service contient un fichier `default-version` qui désigne la variante utilisée lorsqu'aucune version n'est précisée.

```bash
./generate-docker-compose.sh NomService1 NomService2
```

Exemple pour déployer Nginx Proxy Manager et Odoo :

```bash
./generate-docker-compose.sh Nginx-Proxy-Manager Odoo
```

Pour sélectionner explicitement une ancienne version :

```bash
./generate-docker-compose.sh Nginx-Proxy-Manager/Nginx-Proxy-Manager_v2.15.0 Odoo/Odoo_v17
```

Les versions proposées, les variantes historiques et les exceptions non versionnées sont recensées dans [VERSIONS.md](VERSIONS.md).

## Documentation

- [Index de la documentation](docs/README.md)
- [Architecture du dépôt](docs/architecture.md)
- [Guide de déploiement](docs/deployment.md)
- [Guide de migration](docs/migrations.md)
- [Gouvernance du dépôt](docs/governance.md)
- [Décisions d'architecture](decisions/README.md)
- [Guide de contribution](CONTRIBUTING.md)
- [Politique de sécurité](SECURITY.md)
- [Catalogue des versions](VERSIONS.md)

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

## Versions et migrations

### Odoo

La variante par défaut utilise Odoo 19. La variante `Odoo/Odoo_v17` conserve Odoo 17 et son montage de modules personnalisés. Ces modules ne sont volontairement pas montés dans Odoo 19.

Avant une montée majeure, sauvegardez la base et le filestore, demandez une base de test migrée, puis adaptez `ODOO_IMAGE` uniquement après validation. Consultez la [documentation officielle de mise à niveau Odoo](https://www.odoo.com/documentation/19.0/administration/upgrade.html).

Odoo 17 et Odoo 19 utilisent des volumes nommés distincts. Une installation existante basée sur `volumes/postgresql/data` ou `volumes/Odoo/odoo-web-data-client` doit être sauvegardée et migrée explicitement avant le premier démarrage de la nouvelle variante.

`ODOO_LIST_DB=True` permet l'initialisation d'une nouvelle instance. Après création et validation de la base, passez cette variable à `False` et conservez un `ODOO_DB_FILTER` restrictif afin de désactiver le gestionnaire de bases public.

### Nextcloud

La stack classique utilise Nextcloud 34.0.1 par défaut et conserve `Z_Nextcloud/Nextcloud_v33.0.6`. Une instance existante doit installer les versions majeures successivement sans en sauter. Consultez la [procédure officielle de mise à niveau Nextcloud](https://docs.nextcloud.com/server/stable/admin_manual/maintenance/upgrade.html).

Les deux variantes utilisent des volumes distincts. La stack classique ajoute Redis pour le verrouillage et le cache et isole PostgreSQL et Redis sur un réseau interne. Migrez les données et la base après sauvegarde ; ne copiez pas directement un répertoire PostgreSQL entre versions majeures.

Nextcloud AIO suit le canal officiel `ghcr.io/nextcloud-releases/all-in-one:latest` et gère les versions de ses conteneurs depuis son interface. Ne remplacez pas individuellement les images qu'il orchestre. Si le reverse proxy fonctionne dans un conteneur, configurez `NEXTCLOUD_AIO_APACHE_ADDITIONAL_NETWORK` selon la [documentation AIO](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md). L'accès à des répertoires hôte supplémentaires via `NEXTCLOUD_MOUNT` reste volontairement désactivé par défaut.

## Sécurité

### Gestion des mots de passe

- Ne committez jamais `.env`, une clé privée ou un fichier `secret_*.txt`.
- Remplacez toutes les valeurs `CHANGE_ME` avant le premier démarrage.
- Traitez `.env` et les données persistantes comme sensibles ; la configuration Odoo est générée depuis les variables d'environnement.
- Préférez les secrets Docker ou des fichiers montés en lecture seule pour les identifiants de production.

La variante n8n 2.30.5 utilise des volumes Docker séparés (`n8n_2305_data` et `n8n_2305_db_data`). Avant de migrer une installation existante, exportez les workflows et identifiants, sauvegardez PostgreSQL et conservez la même `N8N_ENCRYPTION_KEY`.

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
