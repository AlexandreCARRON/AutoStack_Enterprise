#!/usr/bin/env python3
"""Charge les objets de la démo dans APISIX et prépare Kibana.

Les appels APISIX utilisent des PUT sur des identifiants stables : relancer ce
conteneur réconcilie donc la configuration sans dupliquer les ressources.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ADMIN_URL = os.environ.get("APISIX_ADMIN_URL", "http://apisix:9180").rstrip("/")
ADMIN_KEY = os.environ["APISIX_ADMIN_KEY"]
KIBANA_URL = os.environ.get("KIBANA_URL", "http://kibana:5601").rstrip("/")
LOGSTASH_URL = os.environ.get("LOGSTASH_URL", "http://logstash:8080").rstrip("/")
GENERATED_DIR = Path("/demo/generated")
CERT_DIR = Path("/demo/certs")
ENV_PATTERN = re.compile(r"\$\{([A-Z_][A-Z0-9_]*)\}")


# Remplace récursivement les marqueurs ${VARIABLE} au dernier moment seulement.
def substitute(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: substitute(item) for key, item in value.items()}
    if isinstance(value, list):
        return [substitute(item) for item in value]
    if isinstance(value, str):
        return ENV_PATTERN.sub(lambda match: os.environ[match.group(1)], value)
    return value


# Charge un objet généré et injecte les secrets fournis au conteneur, jamais au dépôt.
def load_json(name: str) -> dict[str, Any]:
    return substitute(json.loads((GENERATED_DIR / name).read_text(encoding="utf-8")))


# Effectue une requête JSON et retourne aussi les erreurs HTTP pour les diagnostiquer.
def request(
    method: str,
    url: str,
    payload: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    timeout: int = 10,
) -> tuple[int, str]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    final_headers = {"Content-Type": "application/json", **(headers or {})}
    req = urllib.request.Request(url, data=body, method=method, headers=final_headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


# Attend une disponibilité HTTP bornée tout en donnant une progression peu bruyante.
def wait_for(name: str, method: str, url: str, headers: dict[str, str] | None = None, attempts: int = 90) -> None:
    for attempt in range(1, attempts + 1):
        try:
            status, _ = request(method, url, headers=headers, timeout=3)
            if 200 <= status < 400:
                print(f"Prêt : {name} ({status})", flush=True)
                return
        except (OSError, urllib.error.URLError):
            pass
        if attempt == 1 or attempt % 10 == 0:
            print(f"Attente de {name} ({attempt}/{attempts})…", flush=True)
        time.sleep(2)
    raise RuntimeError(f"{name} n'est pas devenu disponible : {url}")


# Réconcilie une ressource nommée via l'Admin API et refuse les succès ambigus.
def apisix_put(resource: str, resource_id: str, payload: dict[str, Any]) -> None:
    status, response = request(
        "PUT",
        f"{ADMIN_URL}/apisix/admin/{resource}/{resource_id}",
        payload,
        {"X-API-KEY": ADMIN_KEY},
    )
    if status not in {200, 201}:
        raise RuntimeError(f"APISIX {resource}/{resource_id} a répondu {status}: {response}")
    print(f"Configuré : APISIX {resource}/{resource_id}", flush=True)


# Installe les flux partenaire et SI interne avec leurs consommateurs dédiés.
def configure_apisix() -> None:
    upstream = load_json("upstream.json")
    upstream_id = upstream.pop("id")

    # Le certificat client n'est lu que dans le volume runtime au moment du bootstrap.
    upstream["tls"] = {
        "client_cert": (CERT_DIR / "apisix-client.crt").read_text(encoding="utf-8"),
        "client_key": (CERT_DIR / "apisix-client.key").read_text(encoding="utf-8"),
    }
    apisix_put("upstreams", upstream_id, upstream)

    # L'API interne fictive reste un second upstream distinct du partenaire externe.
    internal_upstream_id = "upstream-api-interne"
    apisix_put(
        "upstreams",
        internal_upstream_id,
        {
            "name": internal_upstream_id,
            "type": "roundrobin",
            "retries": 2,
            "scheme": "http",
            "nodes": {"internal-api:8080": 1},
            "labels": {"autostack-demo": "true", "zone": "internal"},
        },
    )

    consumer = load_json("consumer.json")
    consumer_id = consumer.pop("id")
    credential_id = consumer.pop("credential_id")
    credential = consumer.pop("credential")
    apisix_put("consumers", consumer_id, consumer)
    apisix_put("consumers/{}/credentials".format(consumer_id), credential_id, credential)

    apisix_put(
        "consumers",
        "si-interne",
        {
            "username": "si-interne",
            "labels": {"autostack-demo": "true", "zone": "internal"},
        },
    )
    apisix_put(
        "consumers/si-interne/credentials",
        "si-interne-key",
        {"plugins": {"key-auth": {"key": os.environ["DEMO_INTERNAL_API_KEY"]}}},
    )

    route = load_json("route.json")
    route_id = route.pop("id")
    apisix_put("routes", route_id, route)

    # Les deux routes journalisent vers le même pipeline pour une démonstration corrélable.
    common_plugins = {
        "key-auth": {"header": "X-API-Key", "hide_credentials": True},
        "http-logger": {
            "uri": "http://logstash:8080/apisix",
            "batch_max_size": 1,
            "inactive_timeout": 1,
        },
        "proxy-rewrite": {"regex_uri": ["^/api/interne/?(.*)", "/$1"]},
    }
    apisix_put(
        "routes",
        "route-api-interne",
        {
            "name": "route-api-interne",
            "uri": "/api/interne/*",
            "methods": ["GET", "POST"],
            "upstream_id": internal_upstream_id,
            "plugins": common_plugins,
            "labels": {"autostack-demo": "true", "zone": "internal"},
        },
    )


# Crée la vue de données Kibana ; son échec reste non bloquant pour le routage APISIX.
def configure_kibana() -> None:
    payload = {
        "data_view": {
            "title": "apisix-demo-*",
            "name": "Logs APISIX - Démo AutoStack",
            "timeFieldName": "@timestamp",
            "allowNoIndex": True,
        },
        "override": True,
    }
    status, response = request(
        "POST",
        f"{KIBANA_URL}/api/data_views/data_view",
        payload,
        {"kbn-xsrf": "autostack-demo"},
        timeout=20,
    )
    if status not in {200, 201}:
        print(f"Avertissement : création de la vue Kibana impossible ({status}): {response}", file=sys.stderr)
        return
    try:
        data_view_id = json.loads(response)["data_view"]["id"]
    except (KeyError, TypeError, json.JSONDecodeError):
        print("Avertissement : Kibana n'a pas renvoyé l'identifiant de la vue.", file=sys.stderr)
        return

    # Définir la vue par défaut permet d'ouvrir Discover sans configuration manuelle.
    default_status, default_response = request(
        "POST",
        f"{KIBANA_URL}/api/data_views/default",
        {"data_view_id": data_view_id, "force": True},
        {"kbn-xsrf": "autostack-demo"},
        timeout=20,
    )
    if default_status != 200:
        print(
            f"Avertissement : vue Kibana non définie par défaut ({default_status}): {default_response}",
            file=sys.stderr,
        )
        return
    print("Configuré : vue Kibana par défaut apisix-demo-*", flush=True)


# Attend toutes les dépendances avant d'appliquer la configuration dans un ordre stable.
def main() -> int:
    try:
        wait_for(
            "Admin API APISIX",
            "GET",
            f"{ADMIN_URL}/apisix/admin/routes",
            {"X-API-KEY": ADMIN_KEY},
        )
        wait_for("Logstash HTTP input", "GET", f"{LOGSTASH_URL}/health")
        wait_for("Kibana", "GET", f"{KIBANA_URL}/api/status", attempts=150)
        configure_apisix()
        configure_kibana()
    except (KeyError, OSError, RuntimeError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print(f"Erreur de configuration de la démo : {exc}", file=sys.stderr)
        return 1
    print("Configuration de la démonstration terminée.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
