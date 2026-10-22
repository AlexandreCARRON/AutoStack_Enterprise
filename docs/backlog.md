---
id: autostack.docs.backlog
kind: deliverable
status: active
last_reviewed: 2026-10-02
sensitivity: public
sources: ["docs/README.md", "VERSIONS.md"]
---

# Backlog des services candidats

Ce document recense les services et briques d'infrastructure planifiés ou évalués pour une intégration future dans le catalogue AutoStack Enterprise.

Afin de garantir que le dossier `services/` ne contienne que des stacks testées, reproductibles et conformes aux contrats du dépôt, les briques ci-dessous sont consignées ici jusqu'à la mise à disposition d'un manifeste Docker Compose validé en CI.

---

## 1. Sécurité & Surveillance

### Wazuh
- **Usage :** SIEM open source et plateforme XDR pour la détection des menaces, la surveillance d'intégrité des fichiers (FIM) et la conformité.
- **Statut :** Candidat pour une pile dédiée (manager, indexer, dashboard).
- **Prérequis d'intégration :** Dimensionnement mémoire (gourmand en ressources), initialisation sécurisée des certificats TLS et segmentation réseau.

### ModSecurity + OWASP Core Rule Set (CRS)
- **Usage :** Pare-feu applicatif web (WAF) destiné à filtrer le trafic HTTP/HTTPS en amont des applications.
- **Référence officielle :** [modsecurity-crs-docker](https://github.com/coreruleset/modsecurity-crs-docker/tree/main)
- **Prérequis d'intégration :** Intégration en reverse-proxy en frontal d'APISIX ou de Nginx Proxy Manager avec gestion des faux positifs.

---

## 2. Métrologie & Supervision

### cAdvisor (Container Advisor)
- **Usage :** Analyse et collecte des métriques d'utilisation des ressources conteneurs (CPU, mémoire, I/O réseau et disque).
- **Référence :** [Guide de monitoring conteneurs](https://medium.com/@varunjain2108/monitoring-docker-containers-with-cadvisor-prometheus-and-grafana-d101b4dbbc84)
- **Prérequis d'intégration :** Exposition sécurisée des métriques vers Prometheus (`Prom-Grafana`) sur réseau interne.

### Zabbix
- **Usage :** Solution de monitoring d'infrastructure, réseaux et serveurs.
- **Statut :** Évaluation par rapport au couple Prometheus / Grafana déjà intégré au catalogue.

---

## 3. Productivité & Outils Métier

### Paperless-NGX
- **Usage :** Système de gestion électronique de documents (GED) indexant et océrisant les documents scannés.
- **Référence officielle :** [Documentation Paperless-ngx Docker](https://docs.paperless-ngx.com/setup/#docker)
- **Prérequis d'intégration :** Dépendance PostgreSQL, Redis et moteur d'OCR Tesseract avec persistance des volumes documents.

### Formulaires interactifs (Typeform / Typebot / Formbricks)
- **Usage :** Moteur de formulaires interactifs et questionnaires auto-hébergé.
- **Statut :** Sélection de l'alternative open-source de référence adaptée au modèle Compose léger.

---

## Critères d'entrée dans le catalogue `services/`

Pour être intégré dans `services/`, un candidat doit comporter :
1. Une variante par défaut épinglée avec un tag précis (ex. `services/<Service>/<Service>_vX.Y.Z/`).
2. Un fichier `default-version` désignant la variante par défaut.
3. Un fichier `docker-compose.yml` autonome (fonctionnant isolément et compatible avec le générateur).
4. Un fichier `.env.example` avec des variables préfixées par service et des identifiants `CHANGE_ME`.
5. Une inscription dans [`../VERSIONS.md`](../VERSIONS.md).
