---
id: autostack.measurement.roi-report
kind: summary
status: draft
last_reviewed: 2026-08-03
sensitivity: public
sources: ["measurement/KPI-SELECTION.yml", "measurement/OBSERVATIONS.jsonl"]
---

# Rapport ROI IA — AutoStack Enterprise

**État :** collecte initiale

**Revue :** 2026-08-03

**Catalogue :** `ai-roi.global@1`

## Résultat vérifié

La PR [#4](https://github.com/AlexandreCARRON/AutoStack_Enterprise/pull/4) fournit une première observation calculée : environ `0,257` heure entre sa création et sa fusion. Cette durée est un proxy de délai de réalisation, pas encore une baseline représentative.

## ROI financier

Aucun ROI financier n'est calculable : les coûts IA, le temps humain comparable et la valeur financière des bénéfices ne sont pas disponibles dans ce dépôt public. Les déclarer à zéro produirait un résultat trompeur.

## Limites

- une seule observation comparable ;
- horodatage de pull request utilisé comme proxy du cadrage et de la validation ;
- aucun objectif fixé avant cinq observations ;
- KPI de continuité encore au statut `proposed` ;
- coûts et données individuelles volontairement exclus.

## Prochaine décision

Après cinq tâches ou pull requests terminées, revoir la comparabilité des observations, fixer ou refuser une cible par KPI et décider si la collecte reste manuelle ou mérite une automatisation GitHub Actions.
