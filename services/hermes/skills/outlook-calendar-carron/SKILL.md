---
name: outlook-calendar-carron
description: Lire et gérer un calendrier Outlook avec Microsoft Graph, sans accès aux emails et avec confirmation avant toute notification de participant ou suppression.
---

# Outlook Calendar Carron

Utiliser uniquement :

```bash
python /opt/autostack/hermes-scripts/outlook-calendar-carron.py
```

## Règles obligatoires

- Cette intégration ne doit jamais demander ou utiliser une permission Microsoft Mail, Contacts, Files ou Directory.
- Afficher le titre, la date, l'heure, le fuseau et les participants avant toute création ou modification.
- Ne jamais ajouter de participant ni modifier/supprimer un événement qui en contient sans demande explicite de l'utilisateur. Ajouter alors `--confirm-notify-attendees`.
- Ne jamais supprimer sans demande explicite et sans `--confirm-delete`.
- Ne jamais afficher le contenu des fichiers `outlook_calendar_token.json` ou `outlook_calendar_config.json`.
- Les horaires sont interprétés dans le fuseau configuré, `Romance Standard Time` pour Paris par défaut.

## Consulter

```bash
python /opt/autostack/hermes-scripts/outlook-calendar-carron.py calendars list
python /opt/autostack/hermes-scripts/outlook-calendar-carron.py events list \
  --start 2026-10-07T00:00:00+02:00 --end 2026-10-14T00:00:00+02:00
```

## Créer ou modifier

```bash
python /opt/autostack/hermes-scripts/outlook-calendar-carron.py events create \
  --subject "Rendez-vous" --start 2026-10-07T14:00:00 --end 2026-10-07T14:30:00

python /opt/autostack/hermes-scripts/outlook-calendar-carron.py events update EVENT_ID \
  --subject "Nouveau titre"
```

En présence de participants, expliquer qu'Outlook peut envoyer une invitation ou une mise à jour et demander confirmation avant d'ajouter `--confirm-notify-attendees`.
