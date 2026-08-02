---
id: autostack.migrations
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["../VERSIONS.md"]
---

# Migrations

## Principes communs

Avant tout changement de variante :

1. arrêter les écritures applicatives ;
2. sauvegarder la base et les fichiers persistants ;
3. tester la restauration sur un environnement isolé ;
4. lire les notes de version intermédiaires ;
5. générer la nouvelle variante avec un fichier Compose séparé ;
6. valider fonctionnellement avant de supprimer les anciennes données.

Un retour à l'ancienne image ne garantit pas un rollback lorsque la nouvelle version a modifié le schéma de base.

## PostgreSQL

Entre versions majeures, utilisez `pg_dump` et `pg_restore` ou une procédure `pg_upgrade` officiellement prise en charge. Ne copiez pas directement le répertoire de données.

PostgreSQL 18 utilise `/var/lib/postgresql/18/docker` comme `PGDATA` et déclare `/var/lib/postgresql` comme volume. Les variantes récentes du dépôt montent donc le volume sur `/var/lib/postgresql`.

## Odoo 17 vers Odoo 19

Les volumes `odoo_data` et `odoo_db_data` d'Odoo 17 sont distincts des volumes `odoo19_data` et `odoo19_db_data`.

- migrer la base avec le service de mise à niveau Odoo ou une procédure officiellement supportée ;
- sauvegarder et restaurer le filestore correspondant à la base ;
- porter et tester chaque module personnalisé ;
- ne pas monter l'archive de module Odoo 17 dans la variante Odoo 19 ;
- conserver la même correspondance entre base migrée et filestore.

## Nextcloud 33 vers Nextcloud 34

Nextcloud doit franchir les versions majeures successivement. Les volumes Nextcloud 33 et 34 sont séparés afin d'éviter un démarrage accidentel sur les données historiques.

- sauvegarder PostgreSQL et `/var/www/html` ;
- vérifier la compatibilité des applications installées ;
- activer le mode maintenance pendant la migration ;
- lancer la mise à niveau avec les outils Nextcloud ;
- exécuter les réparations et contrôles recommandés après la mise à niveau.

Nextcloud AIO doit être mis à jour depuis son interface. Ne modifiez pas individuellement les images qu'il orchestre.

## Elastic 8 vers Elastic 9

Le passage depuis 8.15.1 doit utiliser la dernière version 8.19.x comme intermédiaire avant Elastic 9.4.2.

- créer un snapshot vérifié ;
- traiter les dépréciations signalées par Elastic ;
- mettre à niveau vers 8.19.x ;
- valider le cluster et les index ;
- effectuer ensuite la migration vers 9.4.2.

Les volumes `elastic9_*` sont distincts des volumes Elastic 8.

## n8n

La variante 2.30.5 utilise des volumes dédiés et PostgreSQL 18.

- conserver impérativement la même `N8N_ENCRYPTION_KEY` pour relire les identifiants chiffrés ;
- exporter les workflows et identifiants selon les outils n8n ;
- migrer PostgreSQL par export et restauration ;
- vérifier les changements incompatibles des nœuds et des variables d'environnement.

## Outils à stockage local

Pour Jenkins, Portainer, Grafana, Uptime Kuma et Stirling PDF, sauvegardez les volumes applicatifs avant de changer de variante. Vérifiez les notes de version concernant les plugins, bases embarquées, formats de tableaux de bord et paramètres d'authentification.

Les variantes `legacy-unpinned` sont conservées pour consultation. Leur image exacte n'est pas garantie si elles utilisent encore un tag flottant.
