---
id: autostack.apisix
kind: guide
status: active
last_reviewed: 2026-09-09
sensitivity: public
sources: ["https://apisix.apache.org/docs/apisix/installation-guide/", "https://apisix.apache.org/docs/apisix/dashboard/", "https://github.com/apache/apisix-docker/blob/master/example/docker-compose.yml", "https://docs.docker.com/reference/cli/dockerd/#insecure-registries"]
---

# Apache APISIX

La variante par défaut déploie Apache APISIX 3.18.0 et etcd 3.5.18. Elle utilise le Dashboard embarqué dans APISIX ; aucun conteneur `apisix-dashboard` séparé n'est nécessaire.

## Composants et exposition

- `apisix` publie le trafic HTTP sur `9080` et HTTPS sur `9443` par défaut ;
- l'Admin API et le Dashboard sont publiés sur `127.0.0.1:9180` par défaut ;
- `apisix-etcd` n'est pas publié sur l'hôte et conserve ses données dans le volume `apisix_3180_etcd_data` ;
- le réseau interne `apisix-control` transporte uniquement les échanges APISIX ↔ etcd.

Les adresses et ports hôtes sont configurables dans `.env`. L'Admin API exige toujours `APISIX_ADMIN_KEY`.

## Démonstration d'interconnexion complète

La variante `APISIX_demo_v3.18.0` ajoute une API interne fictive, un partenaire HTTPS avec mTLS et une chaîne Logstash → Elasticsearch → Kibana. Elle exploite le classeur fourni pour générer les objets APISIX sans modifier la variante minimale par défaut.

Le [guide de démonstration](DEMO.md) décrit l'architecture, le démarrage automatisé, l'accès depuis VirtualBox et les scénarios de validation.

## Démarrage autonome recommandé

Depuis la racine du dossier APISIX (`cd services/APISIX` dans le dépôt complet) :

```bash
./scripts/install-APISIX.sh
```

Au premier lancement, le script crée `APISIX_v3.18.0/.env` puis s'arrête. Remplacez les valeurs `CHANGE_ME` ; une clé aléatoire peut être créée avec :

```bash
openssl rand -hex 32
```

Relancez ensuite l'installation :

```bash
./scripts/install-APISIX.sh
```

Le script valide Compose, télécharge les images, démarre les conteneurs et affiche leur état. Il résout tous ses chemins depuis le dossier APISIX : le service, ses scripts et ses tests restent donc utilisables après copie isolée.

Dans le dépôt complet, le générateur générique reste disponible depuis la racine avec `./scripts/generate-docker-compose.sh APISIX` pour assembler APISIX avec d'autres services.

Le Dashboard est alors disponible sur <http://127.0.0.1:9180/ui/>. Saisissez la même valeur `APISIX_ADMIN_KEY` lorsqu'il la demande.

## Contournement temporaire d'une inspection TLS

Si `docker compose pull` échoue avec `x509: certificate signed by unknown authority` parce qu'un proxy d'entreprise intercepte Quay, la correction recommandée consiste à installer l'autorité de certification de l'entreprise. Pour un environnement de test Debian 12 où cette correction n'est pas possible, un script peut déclarer temporairement les hôtes Quay comme registres non sécurisés :

```bash
sudo ./scripts/configure-docker-insecure-registries.sh
```

Le script explique comment identifier les domaines en erreur et demande leur liste. Il fusionne ensuite les valeurs dans `/etc/docker/daemon.json`, conserve les autres réglages, crée une sauvegarde, valide le fichier et redémarre Docker. Pendant qu'il attend, effectuez le pull dans une autre fenêtre shell. Après confirmation, le script retire les exceptions, réactive TLS, redémarre Docker et propose de démarrer la stack APISIX avec Compose. En cas d'interruption, il tente également de retirer automatiquement les exceptions avant de quitter.

Cette option affaiblit la vérification de l'origine et de l'intégrité des images. Ne l'utilisez pas en production et ne configurez pas un domaine plus large que nécessaire.

## Vérifications

L'Admin API doit répondre avec la clé configurée :

```bash
set -a
. ./APISIX_v3.18.0/.env
set +a
curl --fail --silent --show-error \
  -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
  "http://127.0.0.1:${APISIX_ADMIN_PORT}/apisix/admin/routes"
```

Créez une route de test vers `httpbin.org` :

```bash
curl --fail --silent --show-error \
  -X PUT \
  -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:${APISIX_ADMIN_PORT}/apisix/admin/routes/httpbin" \
  --data '{
    "uri": "/get",
    "upstream": {
      "type": "roundrobin",
      "pass_host": "node",
      "nodes": {"httpbin.org:80": 1}
    }
  }'

curl --fail --silent --show-error \
  "http://127.0.0.1:${APISIX_HTTP_PORT}/get"
```

Supprimez la route après le test :

```bash
curl --fail --silent --show-error \
  -X DELETE \
  -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
  "http://127.0.0.1:${APISIX_ADMIN_PORT}/apisix/admin/routes/httpbin"
```

## HTTPS et accès distant

Le port `9443` est prévu pour le listener HTTPS d'APISIX. Configurez les certificats et les objets SSL APISIX avant de l'exposer en production.

Ne remplacez `APISIX_ADMIN_BIND_ADDRESS=127.0.0.1` par `0.0.0.0` qu'avec une restriction réseau explicite, un pare-feu et TLS. Pour un accès distant au Dashboard, préférez un tunnel SSH ou un reverse proxy HTTPS protégé.

## Sauvegarde et arrêt

Les routes, upstreams, consommateurs et plugins sont stockés dans etcd. Sauvegardez le volume avant une mise à niveau :

```bash
docker compose exec apisix-etcd \
  /usr/local/bin/etcdctl \
  --endpoints=http://127.0.0.1:2379 \
  snapshot save /tmp/apisix-backup.db

docker compose cp \
  apisix-etcd:/tmp/apisix-backup.db \
  /var/backups/apisix/apisix-backup.db
```

Créez et protégez le répertoire de destination avant la copie. Conservez ensuite le snapshot hors du serveur et testez sa restauration sur une stack isolée.

Arrêter les conteneurs conserve les données :

```bash
docker compose down
```

`docker compose down -v` supprime également le volume etcd et toute la configuration APISIX ; ne l'utilisez que pour une réinitialisation volontaire.

## Ancienne configuration

`APISIX_legacy-unpinned` conserve le POC historique avec images flottantes, IP statiques et ancien Dashboard séparé. Cette variante n'est pas une cible de déploiement. APISIX Dashboard 3.0.1 était la dernière version de l'ancien modèle et n'était testée qu'avec APISIX 3.0 ; les versions récentes intègrent directement l'interface.
