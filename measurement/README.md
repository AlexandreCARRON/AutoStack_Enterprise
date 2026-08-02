---
id: autostack.measurement.guide
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["measurement/KPI-SELECTION.yml"]
---

# Mesure du pilote IA

Ce dossier applique à AutoStack Enterprise le catalogue `ai-roi.global@1` en phase pilote. Il mesure l'effet des méthodes IA sur les tâches du dépôt sans publier de données financières, commerciales ou personnelles.

## Fichiers

- [`KPI-SELECTION.yml`](KPI-SELECTION.yml) sélectionne au plus sept KPI, leurs sources et leur cadence de revue ;
- [`OBSERVATIONS.jsonl`](OBSERVATIONS.jsonl) conserve une observation JSON complète par ligne sans réécrire l'historique ;
- [`ROI-REPORT.md`](ROI-REPORT.md) sépare résultats vérifiés, limites et prochaine décision.

Le validateur se trouve dans [`../scripts/validate_roi_pilot.py`](../scripts/validate_roi_pilot.py). Son test est décrit dans [`../tests/README.md`](../tests/README.md).

## Cycle pilote

1. Enregistrer une observation après la clôture d'une tâche ou la fusion d'une pull request.
2. Référencer des URLs, commits ou exécutions CI vérifiables.
3. Classer la preuve `measured`, `calculated`, `estimated` ou `declared`.
4. Ne pas intégrer `estimated` ou `declared` à un bénéfice vérifié.
5. Revoir les mesures chaque semaine et les KPI après cinq observations comparables.

Les définitions, unités ou agrégations ne sont jamais modifiés rétroactivement. Une évolution crée une nouvelle version du KPI après décision humaine.

## Données exclues

Ce dépôt étant public, ne jamais y enregistrer de coût IA, taux horaire, temps individuel nominatif, secret, donnée client ou information commerciale. Ces données nécessitent un support privé distinct ; elles ne doivent pas être ajoutées à `ai-foundation-carron`, qui ne conserve que les définitions communes et les agrégats non sensibles.
