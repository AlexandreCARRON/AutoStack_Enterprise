# Service n8n

n8n est une plateforme d'automatisation de flux de travail (workflow automation) auto-hébergeable.

## Variantes disponibles

- `N8N_v2.30.5` : variante par défaut, basée sur PostgreSQL 18 et n8n 2.30.5 avec persistance dans des volumes Docker dédiés.
- `N8N_legacy-unpinned` : variante historique non épinglée.

## Déploiement

Pour générer et déployer le service n8n via AutoStack :

```bash
./scripts/generate-docker-compose.sh N8N
```

Ou pour un lancement isolé :

```bash
cd services/N8N/N8N_v2.30.5
cp .env.example .env
docker compose up -d
```

## Documentation complémentaire

- [Guide complet d'installation pas à pas](GUIDE_INSTALLATION.md) (version Markdown).
- Le guide original est également disponible au format Word : [`Guide complet _ Installer N8n sur votre propre serveur.docx`](Guide%20complet%20_%20Installer%20N8n%20sur%20votre%20propre%20serveur.docx).
- [Liens et workflows utiles](Link.md).
