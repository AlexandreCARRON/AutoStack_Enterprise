---
id: autostack.governance
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["AGENTS.md", "decisions/0001-ai-foundation-alignment.md"]
---

# Gouvernance du dépôt

AutoStack applique une adaptation légère des principes de `ai-foundation-carron`. Le dépôt métier reste autonome : il référence les règles transversales utiles, mais ne copie ni les registres, ni les routes, ni les données du socle.

## Principes appliqués

- **Source de vérité :** GitHub et les fichiers versionnés priment sur les états locaux ou les souvenirs de session.
- **Contexte minimal :** une tâche commence par les instructions du dépôt et les fichiers directement concernés.
- **Traçabilité :** une décision durable possède un document dédié ; les sources sont placées près des affirmations.
- **Séparation :** documentation, décisions, mesures, scripts et tests ont des responsabilités distinctes.
- **Sécurité :** aucun secret ni donnée sensible ne doit entrer dans Git ; les exemples restent manifestement fictifs.
- **Vérification :** une règle importante doit autant que possible être contrôlée par un test ou un validateur déterministe.
- **Réversibilité :** les anciennes variantes restent disponibles et les migrations majeures utilisent des données séparées.

## Métadonnées documentaires

Les documents maintenus utilisent un en-tête YAML compatible JSON :

```yaml
---
id: autostack.identifiant-stable
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["README.md"]
---
```

`kind` vaut `fact`, `source`, `decision`, `summary`, `template`, `deliverable`, `policy`, `standard`, `task`, `guide` ou `evaluation`. Une source est obligatoire pour les faits, sources, décisions et synthèses. Les identifiants restent uniques et les dates utilisent le format ISO.

## Niveaux de revue

- **FAST :** correction locale, documentaire ou facilement réversible ;
- **STANDARD :** changement de plusieurs fichiers, nouvelle variante ou décision technique ;
- **DEEP :** exposition de sécurité, perte possible de données, migration majeure ou hypothèse susceptible de changer le résultat.

Le niveau détermine la profondeur de vérification, jamais une permission de charger ou modifier tout le dépôt sans nécessité.

## Contrôles

[`scripts/validate_repository.py`](../scripts/validate_repository.py) contrôle les métadonnées, les liens locaux, les variantes par défaut et quelques traces de secrets. La CI complète ce contrôle avec les tests du générateur, le pilote ROI et la validation Docker Compose.

La décision structurante et les options écartées sont conservées dans [`decisions/0001-ai-foundation-alignment.md`](../decisions/0001-ai-foundation-alignment.md).
