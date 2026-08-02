---
id: autostack.security-policy
kind: policy
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["docs/deployment.md", "docs/migrations.md"]
---

# Politique de sécurité

## Signaler une vulnérabilité

N'ouvrez pas une issue publique contenant une vulnérabilité exploitable, un secret ou des données de production. Utilisez le [signalement privé GitHub](https://github.com/AlexandreCARRON/AutoStack_Enterprise/security/advisories/new) et fournissez uniquement les informations nécessaires à la reproduction.

Le mainteneur confirmera la réception, qualifiera le périmètre et indiquera la prochaine étape. Aucun délai de correction générique ne peut être garanti pour ce projet communautaire.

## Périmètre pris en charge

Les corrections concernent en priorité les variantes indiquées par les fichiers `default-version`. Les variantes historiques sont conservées pour faciliter les migrations, mais elles ne reçoivent pas systématiquement de correctif. Consultez [`VERSIONS.md`](VERSIONS.md) avant un déploiement.

## Responsabilité de déploiement

AutoStack fournit des configurations de référence. Avant une mise en production :

- remplacez toutes les valeurs `CHANGE_ME` ;
- limitez les ports exposés et placez les interfaces administratives derrière TLS ;
- utilisez des secrets Docker ou un gestionnaire de secrets adapté ;
- sauvegardez puis testez la restauration des données ;
- analysez les images et appliquez les mises à jour de sécurité du système hôte.

Le validateur du dépôt détecte quelques erreurs de versionnement évidentes. Il ne remplace pas un scanner de secrets, une analyse de vulnérabilités des images ou une revue humaine du diff.
