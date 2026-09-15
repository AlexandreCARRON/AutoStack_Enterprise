#!/usr/bin/env python3
"""Client éphémère pour les scénarios réseau de la démonstration.

Le statut attendu est vérifié explicitement afin qu'un scénario négatif réussi
(par exemple HTTP 401 sans clé) soit distingué d'une panne réseau.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


# Échange les identifiants techniques contre un jeton sans jamais l'écrire sur disque.
def client_credentials_token() -> str:
    payload = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": os.environ["OIDC_CLIENT_ID"],
            "client_secret": os.environ["OIDC_CLIENT_SECRET"],
        }
    ).encode("ascii")
    request = urllib.request.Request(
        os.environ["OIDC_TOKEN_URL"],
        data=payload,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            token_response = json.loads(response.read())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Keycloak a refusé le client OIDC (HTTP {exc.code})") from exc
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        raise RuntimeError("réponse de jeton Keycloak invalide") from exc

    access_token = token_response.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise RuntimeError("access_token absent de la réponse Keycloak")
    return access_token


# Exécute une requête unique avec ou sans clé APISIX et retourne un code automatisable.
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--without-auth", "--without-key", dest="without_auth", action="store_true")
    parser.add_argument("--expected-status", type=int, default=int(os.environ.get("EXPECTED_STATUS", "200")))
    args = parser.parse_args()

    headers = {"Accept": "application/json"}
    try:
        if not args.without_auth:
            auth_mode = os.environ.get("AUTH_MODE", "api-key")
            if auth_mode == "api-key":
                headers["X-API-Key"] = os.environ["API_KEY"]
            elif auth_mode == "oidc-client-credentials":
                headers["Authorization"] = f"Bearer {client_credentials_token()}"
            else:
                raise RuntimeError(f"mode d'authentification inconnu : {auth_mode}")
    except (KeyError, RuntimeError, urllib.error.URLError) as exc:
        print(f"Authentification impossible : {exc}", file=sys.stderr)
        return 1

    request = urllib.request.Request(os.environ["TARGET_URL"], headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        # Une erreur HTTP peut être le résultat attendu du scénario sans authentification.
        status = exc.code
        body = exc.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as exc:
        print(f"Connexion impossible : {exc}", file=sys.stderr)
        return 1

    print(body)
    if status != args.expected_status:
        print(f"Statut HTTP attendu {args.expected_status}, reçu {status}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
