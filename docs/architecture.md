# Architecture du dépôt

## Organisation générale

```text
AutoStack_Enterprise/
├── services/
│   └── Odoo/
│       ├── default-version
│       ├── Odoo_v17/
│       │   ├── .env.example
│       │   └── docker-compose.yml
│       └── Odoo_v19/
│           ├── .env.example
│           └── docker-compose.yml
├── volumes/
├── docs/
├── generate-docker-compose.sh
├── README.md
└── VERSIONS.md
```

Chaque outil exécutable possède un dossier racine sous `services/`. Ses configurations sont placées dans des sous-dossiers versionnés. Le fichier `default-version` contient le nom exact de la variante sélectionnée lorsque l'utilisateur demande seulement le nom de l'outil.

Les anciens fichiers non épinglés sont conservés dans des variantes suffixées par `legacy-unpinned`. Elles servent de référence et ne doivent pas être considérées comme reproductibles : leur tag `latest` peut avoir changé depuis leur création.

## Générateur

Le script `generate-docker-compose.sh` reçoit une ou plusieurs sélections :

```bash
./generate-docker-compose.sh Odoo Z_Nextcloud
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

Les dossiers ne contenant qu'un lien ou un placeholder ne sont pas intégrés au catalogue exécutable tant qu'aucun fichier Compose validé n'est fourni.
