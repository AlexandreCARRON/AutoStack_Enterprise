#!/usr/bin/env python3
"""Réconcilie les comptes techniques et administrateur de la pile Elastic.

Le conteneur d'initialisation appelle uniquement l'API locale Elasticsearch.
Les secrets proviennent du fichier .env privé et ne sont jamais écrits dans le dépôt.
"""

from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any


ELASTICSEARCH_URL = os.environ.get("ELASTICSEARCH_URL", "http://elasticsearch:9200").rstrip("/")
BOOTSTRAP_USERNAME = "elastic"
BOOTSTRAP_PASSWORD = os.environ["ELASTIC_BOOTSTRAP_PASSWORD"]
ADMIN_USERNAME = os.environ.get("ELASTIC_ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.environ["ELASTIC_ADMIN_PASSWORD"]
KIBANA_SYSTEM_PASSWORD = os.environ["ELASTIC_KIBANA_SYSTEM_PASSWORD"]
LOGSTASH_USERNAME = os.environ.get("ELASTIC_LOGSTASH_USERNAME", "logstash_internal")
LOGSTASH_PASSWORD = os.environ["ELASTIC_LOGSTASH_PASSWORD"]


# Construit l'en-tête Basic sans laisser les identifiants apparaître dans une URL.
def basic_auth(username: str, password: str) -> str:
    token = base64.b64encode(f"{username}:{password}".encode()).decode("ascii")
    return f"Basic {token}"


# Envoie une requête JSON authentifiée et conserve le corps des erreurs HTTP.
def request(method: str, path: str, payload: dict[str, Any] | None = None) -> tuple[int, str]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{ELASTICSEARCH_URL}{path}",
        data=body,
        method=method,
        headers={
            "Authorization": basic_auth(BOOTSTRAP_USERNAME, BOOTSTRAP_PASSWORD),
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


# Attend l'authentification du superutilisateur intégré avant toute écriture.
def wait_for_elasticsearch(attempts: int = 60) -> None:
    for attempt in range(1, attempts + 1):
        try:
            status, response = request("GET", "/_security/_authenticate")
            if status == 200:
                return
            if status in {401, 403}:
                raise RuntimeError(
                    "le mot de passe du compte elastic n'est pas celui attendu ; "
                    "relancez ./scripts/start-apisix-demo.sh pour le réconcilier"
                )
        except (OSError, urllib.error.URLError):
            response = "service indisponible"
        if attempt == 1 or attempt % 10 == 0:
            print(f"Attente d'Elasticsearch ({attempt}/{attempts}) : {response}", flush=True)
        time.sleep(2)
    raise RuntimeError("Elasticsearch n'est pas devenu disponible")


# Exige une réponse de succès pour empêcher une pile partiellement configurée.
def put(path: str, payload: dict[str, Any], label: str) -> None:
    status, response = request("PUT", path, payload)
    if status not in {200, 201}:
        raise RuntimeError(f"{label} a répondu {status}: {response}")
    print(f"Configuré : {label}", flush=True)


def main() -> int:
    try:
        wait_for_elasticsearch()
        put(
            "/_security/user/kibana_system/_password",
            {"password": KIBANA_SYSTEM_PASSWORD},
            "mot de passe du compte technique Kibana",
        )
        put(
            f"/_security/user/{ADMIN_USERNAME}",
            {
                "password": ADMIN_PASSWORD,
                "roles": ["superuser"],
                "full_name": "AutoStack Demo Administrator",
            },
            f"administrateur Elastic {ADMIN_USERNAME}",
        )
        put(
            "/_security/role/autostack_logstash_writer",
            {
                "cluster": ["monitor", "manage_index_templates"],
                "indices": [
                    {
                        "names": ["apisix-demo-*"],
                        "privileges": ["auto_configure", "create_index", "write", "manage"],
                    }
                ],
            },
            "rôle technique Logstash",
        )
        put(
            f"/_security/user/{LOGSTASH_USERNAME}",
            {
                "password": LOGSTASH_PASSWORD,
                "roles": ["autostack_logstash_writer"],
                "full_name": "AutoStack Logstash Service",
            },
            f"compte technique Logstash {LOGSTASH_USERNAME}",
        )
    except (KeyError, OSError, RuntimeError, urllib.error.URLError) as exc:
        print(f"Erreur de configuration Elastic : {exc}", file=sys.stderr)
        return 1
    print("Configuration de la sécurité Elastic terminée.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
