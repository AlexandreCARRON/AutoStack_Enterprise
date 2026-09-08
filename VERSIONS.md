---
id: autostack.versions
kind: fact
status: active
last_reviewed: 2026-09-08
sensitivity: public
sources: ["https://hub.docker.com/", "https://github.com/nextcloud/all-in-one/blob/main/compose.yaml", "https://apisix.apache.org/downloads/", "https://github.com/apache/apisix-docker/blob/master/example/docker-compose.yml"]
---

# Catalogue des versions

Les versions préexistantes ont été vérifiées le 17 juillet 2026 ; APISIX 3.18.0 a été vérifié le 8 septembre 2026. Le nom court d'un service sélectionne la variante indiquée par son fichier `default-version`. Une variante historique doit être appelée avec son chemin complet, par exemple `Odoo/Odoo_v17`.

| Service | Variante par défaut | Variantes conservées | Référence officielle |
| --- | --- | --- | --- |
| Apache APISIX | `APISIX_v3.18.0` | `APISIX_legacy-unpinned` | [APISIX 3.18.0](https://apisix.apache.org/blog/2026/08/20/release-apache-apisix-3.18.0/) |
| Elasticsearch + Kibana | `Elasticsearch-Kibana_v9.4.2` | `Elasticsearch-Kibana_v8.15.1` | [Elastic 9.4.2](https://www.elastic.co/downloads/elasticsearch) |
| Jenkins | `Jenkins_v2.573` | `Jenkins_v2.555.3-LTS`, `Jenkins_legacy-lts` | [Jenkins Docker](https://hub.docker.com/r/jenkins/jenkins/tags/) |
| n8n | `N8N_v2.30.5` | `N8N_legacy-unpinned` | [n8n 2.30.5](https://github.com/n8n-io/n8n/releases/tag/n8n%402.30.5) |
| Nextcloud AIO | `Nextcloud-AIO_latest` | `Nextcloud-AIO_legacy` | [Compose officiel AIO](https://github.com/nextcloud/all-in-one/blob/main/compose.yaml) |
| Nginx Proxy Manager | `Nginx-Proxy-Manager_v2.15.0` | `Nginx-Proxy-Manager_legacy-unpinned` | [NPM 2.15.0](https://github.com/NginxProxyManager/nginx-proxy-manager/releases/tag/v2.15.0) |
| Odoo | `Odoo_v19` | `Odoo_v17` | [Image officielle Odoo](https://hub.docker.com/_/odoo) |
| Portainer CE | `Portainer_v2.43.0` | `Portainer_legacy-unpinned` | [Image Portainer CE](https://hub.docker.com/r/portainer/portainer-ce/tags) |
| Prometheus + Grafana | `Prom-Grafana_v3.13.0-v13.1.0` | `Prom-Grafana_legacy-unpinned` | [Prometheus](https://hub.docker.com/r/prom/prometheus/tags), [Grafana](https://github.com/grafana/grafana/releases/tag/v13.1.0) |
| Uptime Kuma | `Uptime-Kuma_v2.3.2` | `Uptime-Kuma_legacy-unpinned` | [Uptime Kuma 2.3.2](https://github.com/louislam/uptime-kuma/releases/tag/2.3.2) |
| Web-Check | `Web-Check_latest` | `Web-Check_legacy-unpinned` | [Web-Check](https://github.com/Lissy93/web-check) |
| BorgBackup Cron | `Borgbackup-cron_latest` | `Borgbackup-cron_v1.0.0` | [Image BorgBackup Cron](https://hub.docker.com/r/ovski/borgbackup-cron) |
| Grafana OSS | `Grafana-OSS_v13.1.0` | `Grafana-OSS_legacy-unpinned` | [Grafana 13.1.0](https://github.com/grafana/grafana/releases/tag/v13.1.0) |
| Nextcloud classique | `Nextcloud_v34.0.1` | `Nextcloud_v33.0.6` | [Image officielle Nextcloud](https://hub.docker.com/_/nextcloud/) |
| Stirling PDF | `Stirling-PDF_v2.14.0` | `Stirling-PDF_legacy-unpinned` | [Image officielle Stirling PDF](https://hub.docker.com/r/stirlingtools/stirling-pdf/tags) |

## Exceptions aux versions exactes

Nextcloud AIO orchestre et met à jour ses propres images ; son projet officiel demande d'utiliser le canal `ghcr.io/nextcloud-releases/all-in-one:latest`. Web-Check et BorgBackup Cron ne publient pas actuellement de tag sémantique récent. Leurs variantes récentes conservent donc `latest`, tandis que leurs anciennes configurations restent archivées séparément.

## Règles de migration

- Sauvegarder les données applicatives et les bases avant tout changement de variante.
- Traiter chaque changement majeur comme une migration, jamais comme un simple remplacement de tag.
- Tester la restauration avant de supprimer les volumes historiques.
- Ne jamais monter un module Odoo 17 dans Odoo 19 sans portage et validation fonctionnelle.
- Pour PostgreSQL, utiliser `pg_dump` et `pg_restore` entre versions majeures au lieu de copier le répertoire de données.
- Pour Elastic, suivre le chemin pris en charge `8.15.1` → dernière `8.19.x` → `9.4.2` ; les volumes 8 et 9 sont séparés dans ce dépôt.
- Jenkins utilise la version hebdomadaire 2.573 par défaut ; sélectionner `Jenkins/Jenkins_v2.555.3-LTS` pour le canal LTS.
