# Instructions du dépôt

- GitHub est la source de vérité. Vérifier la synchronisation et préserver les changements existants avant toute écriture partagée.
- Commencer avec le contexte minimal : ce fichier, le document ou service ciblé et ses dépendances directes. Approfondir pour une migration majeure, un risque de sécurité ou une décision difficilement réversible.
- Distinguer les faits observés, les hypothèses et les décisions. Ne jamais inventer une version, une compatibilité ou une source.
- Ne jamais versionner de secret, de fichier `.env`, de clé privée, de donnée client ou de donnée personnelle sensible. Les exemples utilisent des valeurs fictives manifestes.
- Conserver les anciennes versions dans leur variante dédiée. Toute nouvelle valeur par défaut met à jour `default-version`, `VERSIONS.md` et la procédure de migration concernée.
- Référencer les workflows réutilisables depuis [`AlexandreCARRON/skills-carron`](https://github.com/AlexandreCARRON/skills-carron) sans recopier leur contenu dans ce dépôt.
- Avant publication, exécuter les contrôles décrits dans [`CONTRIBUTING.md`](CONTRIBUTING.md), examiner le diff et signaler toute validation non exécutée.

Les règles de gouvernance et leur justification sont documentées dans [`docs/governance.md`](docs/governance.md) et [`decisions/`](decisions/README.md).
