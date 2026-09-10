---
id: autostack.architecture
kind: guide
status: active
last_reviewed: 2026-08-03
sensitivity: public
sources: ["../scripts/generate-docker-compose.sh", "../VERSIONS.md"]
---

# Architecture du dépôt

## Organisation générale

```text
AutoStack_Enterprise/
├── services/
│   └── Odoo/
│       ├── default-version
│       ├── scripts/
│       │   └── entrypoint.sh
│       ├── Odoo_v17/
│       │   ├── .env.example
│       │   └── docker-compose.yml
│       └── Odoo_v19/
│           ├── .env.example
│           └── docker-compose.yml
├── volumes/
├── docs/
├── decisions/
├── scripts/
│   ├── generate-docker-compose.sh
│   └── validate_repository.py
├── tests/
├── AGENTS.md
├── README.md
└── VERSIONS.md
```

Chaque outil exécutable possède un dossier racine sous `services/`. Ses configurations sont placées dans des sous-dossiers versionnés. Le fichier `default-version` contient le nom exact de la variante sélectionnée lorsque l'utilisateur demande seulement le nom de l'outil.

Les scripts et tests exclusivement liés à un service sont placés dans `services/<Service>/scripts/` et `services/<Service>/tests/`. La même convention s'applique aux applications et cibles hôte. Les outils et tests génériques restent dans [`scripts/`](../scripts/README.md) et [`tests/`](../tests/README.md) à la racine. Un service doit conserver ses scripts, tests, données de test et chemins Compose lorsqu'il est copié seul ; les manifestes référencent donc une racine de service configurable plutôt que des chemins imposant le dépôt complet.

Lors d'un assemblage, le générateur ajoute `AUTOSTACK_<SERVICE>_DIR=./services/<Service>` au fichier `.env`. Dans un dossier de service copié, chaque manifeste utilise `..` comme racine locale par défaut. Les fichiers de configuration et bind mounts suivis par Git sont conservés sous `services/<Service>/volumes/`.

Les anciens fichiers non épinglés sont conservés dans des variantes suffixées par `legacy-unpinned`. Elles servent de référence et ne doivent pas être considérées comme reproductibles : leur tag `latest` peut avoir changé depuis leur création.

## Générateur

Le script `scripts/generate-docker-compose.sh` reçoit une ou plusieurs sélections :

```bash
./scripts/generate-docker-compose.sh Odoo Z_Nextcloud
```

Pour chaque sélection, il suit le processus suivant :

1. valider le nom du service et empêcher les traversées de chemin ;
2. résoudre `default-version` ou la variante explicitement demandée ;
3. fusionner les services et les sections globales Compose ;
4. agréger les fichiers `.env.example` sans écraser les valeurs locales existantes ;
5. créer `.env` avec les permissions `600` ;
6. refuser les variables ou ressources globales dupliquées.

Les chemins de volumes relatifs restent interprétés depuis le fichier Compose généré à la racine du dépôt, et non depuis le sous-dossier de la variante.

## Données persistantes

Les nouvelles variantes utilisent principalement des volumes Docker nommés. Les changements majeurs à risque disposent de volumes distincts, notamment Elastic 8/9, Odoo 17/19, Nextcloud 33/34 et les nouvelles bases PostgreSQL.

Cette séparation évite qu'une simple sélection de variante démarre un nouveau logiciel sur des données historiques incompatibles. Elle ne remplace pas une procédure de migration.

## Validation continue

La CI exécute :

- la validation syntaxique de tous les scripts Bash ;
- les tests du générateur ;
- `docker compose config --quiet` sur les assemblages représentatifs ;
- `docker compose config --quiet` sur chaque variante historique et récente.
- le contrat documentaire, les liens locaux, les valeurs par défaut et l'hygiène élémentaire des secrets ;
- les tests du validateur ROI et du contrat de dépôt.

Les dossiers ne contenant qu'un lien ou un placeholder ne sont pas intégrés au catalogue exécutable tant qu'aucun fichier Compose validé n'est fourni.

Les règles de maintenance sont décrites dans [la gouvernance](governance.md). Les choix transversaux sont séparés dans [`decisions/`](../decisions/README.md) afin de ne pas confondre état observé et décision durable.
