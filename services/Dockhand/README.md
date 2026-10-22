# Dockhand

Dockhand est une plateforme de gestion et supervision de conteneurs Docker dotée d'une interface web moderne.

## Variantes disponibles

- `Dockhand_v1.0.50` : version épinglée par défaut, avec socket Docker monté en lecture seule (`:ro`) et port d'administration par défaut `22093`.
- `Dockhand_legacy-unpinned` : variante historique non épinglée basée sur le tag `latest`.

## Déploiement

```bash
./scripts/generate-docker-compose.sh Dockhand
```
