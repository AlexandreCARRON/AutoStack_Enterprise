---
id: autostack.decision.ai-foundation-alignment
kind: decision
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["https://github.com/AlexandreCARRON/ai-foundation-carron/blob/main/ai/core.md", "https://github.com/AlexandreCARRON/ai-foundation-carron/blob/main/standards/documentation.md", "https://github.com/AlexandreCARRON/ai-foundation-carron/blob/main/standards/security.md"]
---

# Décision 0001 — Adapter les principes AI Foundation

## Décision

Appliquer un contrat local minimal : `AGENTS.md`, métadonnées des documents maintenus, décisions séparées, politique de sécurité et validation déterministe en CI. Le dépôt ne copie pas les routes, registres d'agents, évaluations ou sources internes de `ai-foundation-carron`.

## Périmètre

La décision couvre la maintenance du catalogue Compose, sa documentation, ses scripts et ses contributions. Elle ne transforme pas AutoStack en dépôt de configuration du socle IA.

## Faits observés

- AutoStack possède déjà des tests de générateur, une CI Compose, une documentation de migration et un pilote ROI.
- Les documents du pilote ROI suivent déjà le schéma documentaire du socle.
- Les autres guides, les décisions techniques et les instructions destinées aux assistants ne formaient pas encore un contrat homogène et vérifié.

## Options comparées

| Option | Valeur | Risque et coût | Réversibilité |
| --- | --- | --- | --- |
| Copier toute la structure AI Foundation | Forte homogénéité apparente | Duplication, dérive et contexte inutile dans un dépôt métier | Faible |
| Ajouter un adaptateur local vérifiable | Règles utiles proches du code et contrôlées en CI | Maintenance limitée du validateur | Forte |
| Ajouter uniquement un lien vers le socle | Très faible coût | Règles non découvrables et non contrôlées | Forte |

## Justification

L'adaptateur local fournit la meilleure valeur opérationnelle sans créer une seconde source de vérité. Il reprend les préceptes observables du socle et laisse les workflows réutilisables dans leur dépôt propriétaire.

## Conséquences

- les nouveaux documents maintenus doivent posséder des métadonnées valides ;
- les choix transversaux sont consignés dans ce dossier ;
- la CI refuse une variante par défaut invalide, un lien local cassé ou certains fichiers sensibles versionnés ;
- la revue humaine et les scanners spécialisés restent nécessaires ;
- le propriétaire du dépôt révise cette décision si les règles du socle changent matériellement.

## Signal de réexamen

Réexaminer cette décision si le validateur local duplique plus de trois contrôles déjà fournis par un outil partagé, si AutoStack devient privé et accueille des données sensibles, ou si une règle AI Foundation doit devenir obligatoire dans plusieurs dépôts métier.
