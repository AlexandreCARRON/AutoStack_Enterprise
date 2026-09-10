---
id: autostack.contributing
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["AGENTS.md", "docs/governance.md"]
---

# Contribuer à AutoStack Enterprise

## Flux de travail

1. Synchroniser la branche avec `main` et vérifier que le worktree ne contient pas de changement à écraser.
2. Limiter la modification au service, au document ou au contrôle concerné.
3. Conserver les anciennes variantes lorsqu'une nouvelle version majeure est ajoutée.
4. Ranger un script générique dans `scripts/` et un script propre à un composant dans le dossier `scripts/` de ce composant.
5. Ajouter ou adapter les tests déterministes.
6. Vérifier le diff, puis ouvrir une pull request qui expose impact, risques, migrations et validations.

Une décision durable ou difficilement réversible est consignée dans [`decisions/`](decisions/README.md). Les hypothèses non vérifiées sont signalées dans la pull request et ne sont pas présentées comme des faits.

## Contrôles locaux

Exécutez au minimum :

```bash
python3 scripts/validate_repository.py
python3 scripts/validate_roi_pilot.py measurement/KPI-SELECTION.yml --observations measurement/OBSERVATIONS.jsonl
python3 -m unittest discover -s tests -v
python3 -m unittest discover -s services/APISIX/tests -v
bash tests/test-generator.sh
```

Pour une modification Compose, validez aussi chaque variante concernée :

```bash
docker compose --env-file services/Odoo/Odoo_v19/.env.example \
  -f services/Odoo/Odoo_v19/docker-compose.yml config --quiet
```

La validation structurelle ne prouve ni la compatibilité des données ni la réussite d'une migration. Une montée majeure exige une sauvegarde restaurable et un essai isolé conformément au [guide de migration](docs/migrations.md).

## Documentation

Les documents maintenus commencent par les métadonnées définies dans [la gouvernance documentaire](docs/governance.md). Les fichiers de conservation comme `fake.md`, les notes de liens historiques et les placeholders ne sont pas concernés tant qu'ils ne deviennent pas une documentation maintenue.

## Sécurité

Ne joignez aucun secret ou extrait de production à une issue ou une pull request. Consultez [`SECURITY.md`](SECURITY.md) pour signaler une vulnérabilité.
