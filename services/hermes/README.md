---
id: autostack.hermes
kind: guide
status: experimental
last_reviewed: 2026-10-20
sensitivity: public
sources: ["https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.24", "https://github.com/NousResearch/hermes-agent/blob/v2026.9.24/docker-compose.yml"]
---

# Hermes — pilote manuel

Module autonome pour le second cerveau, image officielle `v2026.9.24` (release 0.21.5). Aucun fournisseur IA préconfiguré. Le lancement général de la stack ne démarre pas Hermes : le profil `manual` impose une intervention explicite.

## Installation

Pré-requis : Linux avec Docker Engine et Compose, connexion au registre officiel. Depuis cette racine de service :

Prévoir suffisamment d'espace dans les emplacements **Docker et containerd**. Le téléchargement peut réussir mais l'extraction échouer. Sur la VM pilote du 5 octobre, `/var` est une partition séparée de 2,6 Go : l'image n'a pas pu être extraite initialement. Avec accord d'Alexandre, les deux stockages ont été copiés vers `/home/docker-data` et `/home/containerd-data`, hors Git. Configuration Docker `data-root` et configuration containerd `root` adaptées, services vérifiés actifs, originaux et sauvegardes conservés. Deux drop-ins systemd imposent la disponibilité du montage `/home` au démarrage.

Cette migration hôte n'est pas exécutée par le module : elle concerne tous les services Docker. Suivre la [configuration officielle Docker](https://docs.docker.com/engine/daemon/) et sauvegarder configurations et données avant toute adaptation. Sur la VM, les sauvegardes privées sont sous `/home/autostack-storage-backup-20261005.*`, avec script `rollback.sh`. Un retour arrière revient aux données d'avant migration : il faut d'abord sauvegarder les nouvelles données Hermes. Ne rien purger automatiquement.

```bash
bash scripts/install.sh
```

Le script refuse un volume existant pour ne pas écraser une configuration ou des identifiants. Il initialise `autostack_hermes_data`, puis vérifie version, UID et garde-fous. Il ne modifie pas la stack existante. La configuration Compose est copiable avec tout ce dossier ; le générateur AutoStack peut sélectionner `hermes` sans modification de son code.

## Utilisation après choix du fournisseur

```bash
cd hermes_v2026.9.24
docker compose -p autostack-hermes run --rm hermes setup
docker compose -p autostack-hermes run --rm hermes chat
```

L'opérateur réalise lui-même l'authentification et valide les éventuels coûts. Ne jamais copier les codes OAuth ou clés dans Git, les tickets ou une conversation. Après setup, vérifier les garde-fous depuis la racine du service : `bash scripts/verify.sh`.

Raccourci depuis la racine du module : `bash scripts/run.sh --help`, `bash scripts/run.sh setup`, puis `bash scripts/run.sh chat`.

## Gmail et Google Agenda limités

Le pilote Carron ajoute un skill personnel qui sait créer, lister et modifier des **brouillons Gmail**, gérer les événements de l'agenda principal et conserver un registre privé de liens de prise de rendez-vous. Le wrapper ne contient aucune commande d'envoi d'email. L'autorisation `gmail.compose` reste toutefois techniquement capable d'envoyer un brouillon côté Google ; la restriction « brouillon uniquement » est donc appliquée par notre code et vérifiée par les tests, pas par une portée OAuth dédiée qui n'existe pas.

Installer ou actualiser le skill dans le volume privé Hermes :

```bash
bash scripts/install-google-workspace-carron.sh
```

Le skill local est découvert automatiquement par Hermes et le profil active `terminal` pour lui permettre d'appeler le wrapper. Le terminal reste dans le conteneur isolé, avec approbations manuelles, sans socket Docker, dossier Mac ou NAS monté.

L'OAuth limité utilise uniquement `gmail.readonly`, `gmail.compose`, `calendar.readonly` et `calendar.events.owned`. Après avoir placé le client OAuth dans `/opt/data/google_client_secret.json`, lancer le flux avec :

```bash
bash scripts/run.sh python /opt/autostack/hermes-scripts/google-workspace-oauth-carron.py --auth-url
```

Après validation dans Google, la redirection `localhost:1` affiche normalement une erreur. Depuis un terminal SSH ouvert sur la VM, lancer `bash scripts/complete-google-oauth-carron.sh`, puis y coller l'URL complète de la barre d'adresse. La saisie reste masquée et ne transite pas dans la conversation. Ne jamais transmettre le code, le jeton ou le secret client dans Git ou dans une conversation persistante.

Google Calendar ne fournit pas d'API publique pour créer ou modifier les pages de prise de rendez-vous. Hermes peut mémoriser leurs URL et les insérer dans des brouillons ou événements ; la création et la modification de la page elle-même restent manuelles dans Google Calendar.

## Calendrier Outlook limité

Le skill `outlook-calendar-carron` utilise Microsoft Graph avec le flux OAuth par code d'appareil, adapté à la VM sans navigateur. Il demande uniquement `offline_access` et la permission déléguée `Calendars.ReadWrite` : aucun droit Mail, Contacts, Files ou Directory. Installer le skill avec :

```bash
bash scripts/install-outlook-calendar-carron.sh
```

Créer d'abord une application publique dans Microsoft Entra, autorisant les comptes Microsoft voulus et le flux client public, puis enregistrer son identifiant d'application dans le volume privé Hermes :

```bash
bash scripts/run.sh python /opt/autostack/hermes-scripts/outlook-calendar-auth-carron.py configure \
  --client-id UUID-DE-L-APPLICATION --tenant common
bash scripts/run.sh python /opt/autostack/hermes-scripts/outlook-calendar-auth-carron.py login
```

Le terminal affiche une URL Microsoft et un code temporaire à saisir dans le navigateur. Ne jamais publier ce code ni les jetons. Les écritures qui peuvent prévenir des participants nécessitent `--confirm-notify-attendees`, et les suppressions nécessitent également `--confirm-delete`.

## Connexion GitHub limitée

Créer un jeton personnel GitHub à granularité fine, avec une date d'expiration et uniquement les dépôts nécessaires. Pour un usage de développement contrôlé, accorder `Contents`, `Issues` et `Pull requests` en lecture/écriture, `Actions` en lecture seule, sans permission d'administration, de gestion des secrets, de suppression ou d'écriture des workflows.

Depuis la racine du module, saisir le jeton dans le terminal lorsque le script le demande :

```bash
bash scripts/configure-github.sh OWNER/REPO [OWNER/REPO ...]
```

Le jeton transite uniquement par l'entrée standard, puis est stocké dans `/opt/data/.env` dans le volume privé Hermes avec le mode `600`. Il n'est ni affiché ni écrit dans Git. Un helper Git limité à `https://github.com` lit ce jeton pour les opérations HTTPS. Le script vérifie ensuite l'identité GitHub et les droits `pull`/`push` sur chaque dépôt indiqué, sans créer de branche, issue ou pull request.

Relancer ultérieurement le contrôle non destructif avec :

```bash
bash scripts/verify-github.sh OWNER/REPO [OWNER/REPO ...]
```

## Limites du pilote

- Aucun port publié, dashboard ou gateway démarré volontairement ; pas de flux planifié configuré.
- Aucun dossier personnel, dépôt second cerveau, NAS ou socket Docker monté. Les identifiants Google restent dans le volume privé Hermes.
- Outils CLI limités aux fichiers dans le conteneur, tâches, mémoire et terminal isolé ; pas de navigateur, cron ou délégation dans la liste autorisée.
- Approbations manuelles et validation des écritures mémoire/skills, installations opportunistes désactivées. Ces contrôles applicatifs ne remplacent pas l'isolation du conteneur.
- L'image démarre son initialisation comme root, puis exécute la CLI comme UID 10000 selon son mécanisme officiel ; ne pas forcer `user:`.
- Image figée par tag et digest immuable `sha256:fca358f12efd65bfaaca05884166f15c0e2788375ca30d77061ac1ebc96452b7`, vérifiée sur Debian 13 ARM64. Compatibilité d'autres architectures non testée.
- Aucun appel de modèle effectué par les contrôles d'installation. Un vrai test IA reste requis.

Le volume peut contenir secrets et conversations : sauvegarde privée chiffrée avant migration. Ne pas utiliser `down -v` ou supprimer ce volume sans accord. Les conteneurs `run --rm` disparaissent à la fermeture ; les données persistent. Une ancienne variante doit être conservée lors d'une mise à jour.
