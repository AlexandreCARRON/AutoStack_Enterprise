---
id: autostack.deployment
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["../generate-docker-compose.sh", "../SECURITY.md"]
---

# Déploiement

## Choisir une variante

Le nom court sélectionne la version indiquée par `default-version` :

```bash
./generate-docker-compose.sh Odoo
```

Une ancienne version se sélectionne avec son chemin relatif sous `services/` :

```bash
./generate-docker-compose.sh Odoo/Odoo_v17
```

Plusieurs outils peuvent être assemblés :

```bash
./generate-docker-compose.sh \
  Nginx-Proxy-Manager \
  Odoo/Odoo_v19 \
  N8N/N8N_v2.30.5
```

Consultez [le catalogue](../VERSIONS.md) pour connaître les variantes disponibles.

## Préparer l'environnement

Au premier lancement, le générateur crée `.env`. Remplacez chaque valeur `CHANGE_ME` et vérifiez notamment :

- les mots de passe applicatifs et PostgreSQL ;
- les domaines publics et les URL de webhook ;
- les adresses d'écoute des ports ;
- les réseaux de reverse proxy ;
- les chemins de sauvegarde et les fichiers de secrets.

Le fichier `.env` ne doit jamais être committé.

## Valider la configuration

```bash
docker compose config --quiet
```

La validation doit être relancée après chaque changement de variante ou de variable. Elle vérifie la structure Compose, mais pas la compatibilité des données existantes.

## Démarrer

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Vérifiez ensuite les journaux et les healthchecks :

```bash
docker compose logs --tail=100
docker compose ps
```

## Régénérer un assemblage

Le générateur protège le fichier Compose existant. Pour le remplacer volontairement :

```bash
FORCE=1 ./generate-docker-compose.sh Odoo N8N
```

Les valeurs déjà présentes dans `.env` sont conservées et seules les variables manquantes sont ajoutées.

## Exposition réseau

Les interfaces d'administration récentes sont liées à `127.0.0.1` par défaut lorsqu'elles sont destinées à être publiées derrière un reverse proxy. Nginx Proxy Manager conserve les ports publics `80` et `443` sur toutes les interfaces.

Modifier une adresse d'écoute vers `0.0.0.0` constitue une exposition explicite. Protégez alors le port avec le pare-feu, TLS et une authentification appropriée.
