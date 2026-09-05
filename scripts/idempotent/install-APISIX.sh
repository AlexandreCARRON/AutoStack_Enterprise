#!/bin/bash

set -euo pipefail

NETWORK_NAME="apisix"
ETCD_IP="172.18.5.10"
APISIX_IP="172.18.5.11"

echo "====================================="
echo "Nettoyage"
echo "====================================="

docker rm -f test-api-gateway etcd-server 2>/dev/null || true
docker network rm ${NETWORK_NAME} 2>/dev/null || true

echo "====================================="
echo "Création du réseau"
echo "====================================="

docker network create \
    --driver bridge \
    --subnet=172.18.0.0/16 \
    --ip-range=172.18.5.0/24 \
    --gateway=172.18.5.254 \
    ${NETWORK_NAME}

mkdir -p apisix_conf
mkdir -p apisix_logs

echo "====================================="
echo "Configuration APISIX"
echo "====================================="

cat > apisix_conf/config.yaml <<EOF
deployment:
  role: traditional

  admin:
    allow_admin:
      - 0.0.0.0/0

    admin_key:
      -
        name: admin
        key: edd1c9f034335f136f87ad84b625c8f1
        role: admin

  etcd:
    host:
      - "http://${ETCD_IP}:2379"
EOF

echo "====================================="
echo "Téléchargement des images"
echo "====================================="

docker pull quay.io/coreos/etcd:v3.5.18
docker pull apache/apisix:latest

echo "====================================="
echo "Démarrage ETCD"
echo "====================================="

docker run -d \
  --name etcd-server \
  --network ${NETWORK_NAME} \
  --ip ${ETCD_IP} \
  -p 2379:2379 \
  -p 2380:2380 \
  quay.io/coreos/etcd:v3.5.18 \
  /usr/local/bin/etcd \
  --name etcd0 \
  --advertise-client-urls http://0.0.0.0:2379 \
  --listen-client-urls http://0.0.0.0:2379

echo "Attente ETCD..."
sleep 15

echo "====================================="
echo "Test ETCD"
echo "====================================="

curl http://localhost:2379/version
echo ""

echo "====================================="
echo "Démarrage APISIX"
echo "====================================="

docker run -d \
  --name test-api-gateway \
  --network ${NETWORK_NAME} \
  --ip ${APISIX_IP} \
  -p 9080:9080 \
  -p 9091:9091 \
  -p 9443:9443 \
  -v "$(pwd)/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml" \
  -v "$(pwd)/apisix_logs:/usr/local/apisix/logs" \
  apache/apisix:latest

echo "Attente APISIX..."
sleep 30

echo "====================================="
echo "Containers actifs"
echo "====================================="

docker ps

echo "====================================="
echo "Test Admin API"
echo "====================================="

curl -s \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  http://127.0.0.1:9180/apisix/admin/routes

echo ""
echo "====================================="
echo "Création d'une route"
echo "====================================="

curl -i \
  http://127.0.0.1:9180/apisix/admin/routes/1 \
  -X PUT \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -d '
{
  "uri":"/get",
  "upstream":{
    "type":"roundrobin",
    "nodes":{
      "httpbin.org:80":1
    }
  }
}'

echo ""
echo "====================================="
echo "Test de la route"
echo "====================================="

sleep 5

curl -i http://127.0.0.1:9080/get

echo ""
echo "====================================="
echo "Déploiement terminé"
echo "====================================="
