#!/bin/bash

set -euo pipefail

echo "=================================================="
echo "APISIX - Déploiement complet"
echo "=================================================="

# Nettoyage éventuel
docker rm -f test-api-gateway etcd-server 2>/dev/null || true
docker network rm apisix 2>/dev/null || true

# Création du réseau
echo "[1/8] Création du réseau Docker"

docker network create \
  --driver=bridge \
  --subnet=172.18.0.0/16 \
  --ip-range=172.18.5.0/24 \
  --gateway=172.18.5.254 \
  apisix

# Répertoires
mkdir -p apisix_conf
mkdir -p apisix_logs

# Configuration APISIX
echo "[2/8] Génération config APISIX"

cat > apisix_conf/config.yaml <<EOF
deployment:
  admin:
    allow_admin:
      - 0.0.0.0/0
    admin_key:
      - name: admin
        key: edd1c9f034335f136f87ad84b625c8f1
        role: admin

  etcd:
    host:
      - "http://172.18.5.10:2379"

apisix:
  node_listen: 9080

nginx_config:
  error_log: "/usr/local/apisix/logs/error.log"
EOF

# ETCD
echo "[3/8] Démarrage ETCD"

docker run -d \
  --name etcd-server \
  --network apisix \
  --ip 172.18.5.10 \
  -p 2379:2379 \
  -p 2380:2380 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  bitnami/etcd:3.4.9

echo "Attente ETCD..."
sleep 20

# APISIX
echo "[4/8] Démarrage APISIX"

docker run -d \
  --name test-api-gateway \
  --network apisix \
  --ip 172.18.5.11 \
  -p 9080:9080 \
  -p 9091:9091 \
  -p 9443:9443 \
  -v "$(pwd)/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml" \
  -v "$(pwd)/apisix_logs:/usr/local/apisix/logs" \
  apache/apisix

echo "Attente APISIX..."
sleep 30

# Vérification containers
echo "[5/8] Vérification des conteneurs"

docker ps \
  --filter name=etcd-server \
  --filter name=test-api-gateway

# Test ETCD
echo "[6/8] Test ETCD"

curl -s http://localhost:2379/version || true

# Test APISIX Admin API
echo "[7/8] Test Admin API"

curl -s \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://127.0.0.1:9080/apisix/admin/routes || true

# Création route de test
echo "[8/8] Création d'une route"

curl -i http://127.0.0.1:9080/apisix/admin/routes/1 \
  -X PUT \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -d '
{
  "uri": "/get",
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

echo
echo "=================================================="
echo "Tests finaux"
echo "=================================================="
echo

curl -i http://127.0.0.1:9080/get

echo
echo
echo "Déploiement APISIX terminé.Essaie http://127.0.0.1:9080"
