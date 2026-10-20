---
name: google-workspace-carron
description: Créer et gérer des brouillons Gmail, gérer les événements du calendrier personnel et conserver les liens de prise de rendez-vous, sans jamais envoyer de mail.
---

# Google Workspace Carron

Utiliser uniquement le wrapper limité suivant :

```bash
python /opt/autostack/hermes-scripts/google-workspace-carron.py
```

## Règles obligatoires

- Ne jamais utiliser le sous-module Google Workspace générique pour envoyer ou répondre à un mail.
- Ne jamais appeler l'API Gmail `messages.send` ni une commande `gmail send` ou `gmail reply`.
- Pour un email, créer ou modifier uniquement un brouillon, puis donner son identifiant à l'utilisateur pour validation dans Gmail.
- Afficher les paramètres essentiels avant une écriture externe : destinataires, objet, date et horaires concernés.
- Ne supprimer un brouillon, un événement ou un lien qu'après une demande explicite de l'utilisateur ; ajouter alors `--confirm-delete`.
- Les créations et modifications d'événements utilisent `sendUpdates=none` : elles ne préviennent pas automatiquement les invités.
- Les pages Google de prise de rendez-vous ne sont pas administrables par l'API Calendar. Le registre local conserve leurs URL et permet de les réutiliser dans les brouillons et événements.
- Ne jamais afficher le contenu de `google_token.json` ou `google_client_secret.json`.

## Gmail — brouillons uniquement

Pour éviter les problèmes d'échappement, écrire le corps dans un fichier temporaire sous `/opt/data/workspace`, puis utiliser `--body-file`.

```bash
python /opt/autostack/hermes-scripts/google-workspace-carron.py gmail draft-create \
  --to destinataire@example.com --subject "Objet" --body-file /opt/data/workspace/brouillon.txt

python /opt/autostack/hermes-scripts/google-workspace-carron.py gmail draft-list --max 20

python /opt/autostack/hermes-scripts/google-workspace-carron.py gmail draft-update DRAFT_ID \
  --to destinataire@example.com --subject "Objet corrigé" --body-file /opt/data/workspace/brouillon.txt
```

## Calendrier

Toujours utiliser des horodatages ISO 8601 avec fuseau, par exemple `2026-10-06T14:00:00+02:00`.

```bash
python /opt/autostack/hermes-scripts/google-workspace-carron.py calendar list \
  --start 2026-10-06T00:00:00+02:00 --end 2026-10-13T00:00:00+02:00

python /opt/autostack/hermes-scripts/google-workspace-carron.py calendar create \
  --summary "Rendez-vous" --start 2026-10-06T14:00:00+02:00 --end 2026-10-06T14:30:00+02:00

python /opt/autostack/hermes-scripts/google-workspace-carron.py calendar update EVENT_ID \
  --summary "Nouveau titre"
```

## Liens de prise de rendez-vous

```bash
python /opt/autostack/hermes-scripts/google-workspace-carron.py booking list
python /opt/autostack/hermes-scripts/google-workspace-carron.py booking add "30 minutes" "https://calendar.app.google/..."
```
