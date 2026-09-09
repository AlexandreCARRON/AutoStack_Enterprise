#!/usr/bin/env python3
"""Client éphémère pour les scénarios réseau de la démonstration."""

from __future__ import annotations

import argparse
import os
import sys
import urllib.error
import urllib.request


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--without-key", action="store_true")
    parser.add_argument("--expected-status", type=int, default=int(os.environ.get("EXPECTED_STATUS", "200")))
    args = parser.parse_args()

    headers = {"Accept": "application/json"}
    if not args.without_key:
        headers["X-API-Key"] = os.environ["API_KEY"]
    request = urllib.request.Request(os.environ["TARGET_URL"], headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.status
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
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
