# Guide complet : Installer N8N sur votre propre serveur avec CapRover

> **Auteur :** Fabien Bousquet ([LinkedIn](https://www.linkedin.com/in/fabienbousquet/))  
> **Source :** Document de formation initiale  
> **Niveau :** Débutant - Pas à pas  
> *Ce guide conserve le tutoriel original accompagnant le fichier binaire.*

---

## Introduction

N8N est un outil d'automatisation puissant qui vous permet de connecter différentes applications ensemble (Gmail, Google Sheets, Slack, etc.) et de créer des flux automatisés sur votre propre infrastructure.

---

## Table des matières

1. [Comprendre les bases](#1-comprendre-les-bases)
2. [Préparer votre serveur](#2-préparer-votre-serveur)
3. [Configuration de votre domaine](#3-configuration-de-votre-domaine)
4. [Installer N8N](#4-installer-n8n)
5. [Configurer les mises à jour automatiques (Watchtower)](#5-configurer-les-mises-à-jour-automatiques)
6. [Sécuriser votre installation (UFW & Fail2ban)](#6-sécuriser-votre-installation)
7. [Penser aux sauvegardes](#7-penser-aux-sauvegardes)
8. [Maintenance et bonnes pratiques](#8-maintenance-et-bonnes-pratiques)

---

## 1. Comprendre les bases

- **VPS (Virtual Private Server) :** Serveur virtuel distant fonctionnant 24h/24 pour héberger vos applications.
- **Terminal :** Interface en ligne de commande permettant de piloter le serveur à distance.
- **SSH :** Protocole sécurisé pour ouvrir une session chiffrée sur le VPS.

**Prérequis :**
- Environ 1 heure de temps.
- Un terminal (PuTTY sous Windows, Terminal sous macOS/Linux).

---

## 2. Préparer votre serveur

### 2.1 Choix de l'hébergeur et configuration
- Exemple de dimensionnement minimal recommandé : 2 vCPU, 8 Go de RAM, 50 à 100 Go de stockage NVMe/SSD.
- Système d'exploitation : Ubuntu 22.04 / 24.04 LTS ou Debian 12.
- Configurer une clé SSH pour l'accès administrateur `root`.

### 2.2 Connexion SSH
```bash
ssh root@VOTRE_IP_SERVEUR
```

### 2.3 Installation de Docker et CapRover
```bash
# Mise à jour du système
apt update && apt upgrade -y

# Installation de Docker officiel
curl -fsSL https://get.docker.com | bash
docker -v

# Lancement du conteneur CapRover
docker run -p 80:80 -p 443:443 -p 3000:3000 -e ACCEPTED_TERMS=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /captain:/captain \
  caprover/caprover
```

---

## 3. Configuration de votre domaine

### 3.1 Entrées DNS chez votre registrar
Créez les entrées de type `A` pointant vers l'adresse IP de votre serveur :

| Type | Nom | Valeur |
| :--- | :--- | :--- |
| A | `app` | `VOTRE_IP_SERVEUR` |
| A | `*.app` | `VOTRE_IP_SERVEUR` |

Attendez la propagation DNS (5 à 30 minutes).

### 3.2 Configuration CLI CapRover
```bash
# Installation de Node.js et du CLI CapRover
sudo apt-get install -y nodejs npm
sudo npm i -g caprover

# Assistant de configuration
caprover serversetup
```
Suivez les invites interactives (IP, mot de passe initial `captain42`, nom de domaine principal).

---

## 4. Installer N8N

### 4.1 Déploiement via CapRover One-Click Apps
1. Dans l'interface web CapRover (`https://captain.app.votredomaine.com`) :
2. Rendez-vous dans **Apps** > **One-Click Apps/Databases**.
3. Sélectionnez **n8n**.
4. Cochez **Has Persistent Data**.
5. Renseignez les paramètres (identifiants base PostgreSQL, fuseau horaire `Europe/Paris`, paramètres SMTP).
6. Cliquez sur **Deploy**.

### 4.2 Clé de chiffrement N8N
Générez une clé de chiffrement forte dans votre terminal :
```bash
openssl rand -hex 32
```
Dans CapRover (**Apps** > **n8n** > **App Configs** > **Environment Variables**), ajoutez :
```env
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_ENCRYPTION_KEY=<votre_clé_générée>
```
Sauvegardez et redémarrez le conteneur.

### 4.3 Activation TLS/HTTPS
Dans CapRover : **Apps** > **n8n** > **Enable HTTPS** puis activez la redirection automatique HTTP vers HTTPS.

---

## 5. Configurer les mises à jour automatiques

Déploiement de **Watchtower** pour la gestion automatisée du cycle de vie des conteneurs :
1. Créez une application `watchtower` avec données persistantes activées.
2. Cochez **Do not expose as web-app externally**.
3. Définissez les variables d'environnement :
```env
TZ=Europe/Paris
WATCHTOWER_CLEANUP=true
WATCHTOWER_SCHEDULE=0 0 4 * * *
WATCHTOWER_TIMEOUT=180s
WATCHTOWER_ROLLING_RESTART=true
```
4. Déployez avec l'image `containrrr/watchtower`.

---

## 6. Sécuriser votre installation

### 6.1 Pare-feu (UFW)
```bash
sudo apt-get install -y ufw

# Règles par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Port SSH (vérifiez votre port avant activation !)
sudo ufw allow ssh

# Ports applicatifs et swarm CapRover
sudo ufw allow 80,443,3000,996,7946,4789,2377/tcp
sudo ufw allow 7946,4789,2377,443/udp

# Activation
sudo ufw enable
sudo ufw status numbered
```

### 6.2 Protection Fail2ban
Configuration dans `/etc/fail2ban/jail.local` :
```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
banaction = ufw
banaction_allports = ufw

[sshd]
enabled = true
maxretry = 3
bantime = 24h

[n8n]
enabled = true
port = http,https
filter = n8n
maxretry = 5
bantime = 1h
```

Filtre pour N8N dans `/etc/fail2ban/filter.d/n8n.conf` :
```ini
[Definition]
failregex = ^<HOST> .* "POST /webhook.*" (401|403|404)
            ^<HOST> .* "POST /api/.*" (401|403|404)
ignoreregex =
```
Activez le service :
```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status
```

---

## 7. Penser aux sauvegardes

- **Sauvegarde des workflows :** Mettre en place un workflow N8N planifié exportant quotidiennement tous les workflows et identifiants chiffrés au format `.json` vers un stockage sécurisé distant (S3, Google Drive, Nextcloud).
- **Sauvegarde de la base de données :** Utiliser `pg_dump` pour sauvegarder la base de données PostgreSQL de N8N.
- **Rétention :** Programmer un nettoyage automatique des sauvegardes de plus de 30 jours.

---

## 8. Maintenance et bonnes pratiques

1. Surveillez régulièrement les journaux d'exécution dans CapRover ou via `docker logs`.
2. Testez systématiquement les workflows critiques sur des jeux de données d'essai avant activation en production.
3. Conservez impérativement la variable `N8N_ENCRYPTION_KEY` dans un gestionnaire de mots de passe hors du serveur : sans cette clé, les identifiants enregistrés dans les nœuds deviennent irrécupérables.