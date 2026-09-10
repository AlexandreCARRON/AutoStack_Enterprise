#!/usr/bin/env python3
"""API HTTP/HTTPS minimale utilisée uniquement par la démonstration APISIX.

Le même serveur simule soit le SI interne, soit le partenaire externe selon
DEMO_API_ROLE. Il ne doit pas être utilisé comme serveur applicatif de production.
"""

from __future__ import annotations

import json
import os
import ssl
from datetime import UTC, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import PurePosixPath
from typing import Any


ROLE = os.environ.get("DEMO_API_ROLE", "internal")
PORT = int(os.environ.get("DEMO_API_PORT", "8080"))
PARTNER_BACKEND_API_KEY = os.environ.get("DEMO_PARTNER_BACKEND_API_KEY", "")


# Implémente uniquement les endpoints nécessaires aux scénarios documentés.
class DemoHandler(BaseHTTPRequestHandler):
    server_version = "AutoStackDemoAPI/1.0"

    # Émet des journaux JSON structurés pour rester lisible dans docker compose logs.
    def log_message(self, message: str, *args: object) -> None:
        print(
            json.dumps(
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "role": ROLE,
                    "remote": self.client_address[0],
                    "message": message % args,
                }
            ),
            flush=True,
        )

    # Accepte du JSON ou conserve le texte brut pour rendre la démo tolérante aux payloads.
    def _body(self) -> Any:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw.decode("utf-8", errors="replace")

    # Uniformise toutes les réponses et fixe explicitement leur longueur HTTP.
    def _reply(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        raw = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    # Retourne les en-têtes ajoutés par APISIX afin de rendre le routage observable.
    def _request_context(self) -> dict[str, Any]:
        return {
            "method": self.command,
            "path": self.path,
            "consumer": self.headers.get("X-Consumer-Username"),
            "request_id": self.headers.get("X-Request-Id"),
        }

    # Le backend partenaire exige la clé posée par proxy-rewrite, jamais celle du client.
    def _partner_authorized(self) -> bool:
        if ROLE != "partner":
            return True
        supplied = self.headers.get("X-Partner-Api-Key", "")
        if PARTNER_BACKEND_API_KEY and supplied == PARTNER_BACKEND_API_KEY:
            return True
        self._reply(
            HTTPStatus.UNAUTHORIZED,
            {"service": "partenaire_A", "error": "partner backend API key missing or invalid"},
        )
        return False

    # Simule la lecture de commandes internes ou l'état du partenaire selon le rôle.
    def do_GET(self) -> None:  # noqa: N802 - API BaseHTTPRequestHandler
        if self.path == "/health":
            self._reply(HTTPStatus.OK, {"status": "healthy", "role": ROLE})
            return

        if not self._partner_authorized():
            return

        path = PurePosixPath(self.path.split("?", 1)[0])
        if ROLE == "internal" and str(path) in {"/", "/orders"}:
            self._reply(
                HTTPStatus.OK,
                {
                    "service": "api-interne-commandes",
                    "orders": [
                        {"id": "CMD-1001", "partner": "partenaire_A", "status": "ACCEPTED"},
                        {"id": "CMD-1002", "partner": "partenaire_A", "status": "SHIPPED"},
                    ],
                    "request": self._request_context(),
                },
            )
            return

        if ROLE == "internal" and len(path.parts) == 3 and path.parts[1] == "orders":
            self._reply(
                HTTPStatus.OK,
                {
                    "service": "api-interne-commandes",
                    "order": {"id": path.parts[2], "status": "ACCEPTED"},
                    "request": self._request_context(),
                },
            )
            return

        if ROLE == "partner" and str(path) in {"/", "/status"}:
            # Le certificat pair prouve que la terminaison cliente mTLS vient d'APISIX.
            peer = self.connection.getpeercert() if hasattr(self.connection, "getpeercert") else None
            self._reply(
                HTTPStatus.OK,
                {
                    "service": "backend-partenaire-a",
                    "partner": "partenaire_A",
                    "status": "AVAILABLE",
                    "mtls_client": peer.get("subject") if peer else None,
                    "request": self._request_context(),
                },
            )
            return

        self._reply(HTTPStatus.NOT_FOUND, {"error": "not found", "request": self._request_context()})

    # Simule la création d'une commande ou l'envoi d'un message au partenaire.
    def do_POST(self) -> None:  # noqa: N802 - API BaseHTTPRequestHandler
        if not self._partner_authorized():
            return

        path = PurePosixPath(self.path.split("?", 1)[0])
        body = self._body()
        if ROLE == "internal" and str(path) == "/orders":
            self._reply(
                HTTPStatus.CREATED,
                {
                    "service": "api-interne-commandes",
                    "order": {"id": "CMD-DEMO", "status": "ACCEPTED", "payload": body},
                    "request": self._request_context(),
                },
            )
            return

        if ROLE == "partner" and str(path) == "/messages":
            # Le sujet client est renvoyé pour rendre la preuve mTLS visible pendant la démo.
            peer = self.connection.getpeercert() if hasattr(self.connection, "getpeercert") else None
            self._reply(
                HTTPStatus.ACCEPTED,
                {
                    "service": "backend-partenaire-a",
                    "status": "RECEIVED",
                    "payload": body,
                    "mtls_client": peer.get("subject") if peer else None,
                    "request": self._request_context(),
                },
            )
            return

        self._reply(HTTPStatus.NOT_FOUND, {"error": "not found", "request": self._request_context()})


# Démarre en HTTP simple ou en HTTPS/mTLS strict selon les variables de certificats.
def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), DemoHandler)
    cert_file = os.environ.get("DEMO_TLS_CERT")
    key_file = os.environ.get("DEMO_TLS_KEY")
    ca_file = os.environ.get("DEMO_TLS_CLIENT_CA")

    if cert_file and key_file:
        # TLS 1.2 minimum et certificat client obligatoire dès qu'une CA est fournie.
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(certfile=cert_file, keyfile=key_file)
        if ca_file:
            context.verify_mode = ssl.CERT_REQUIRED
            context.load_verify_locations(cafile=ca_file)
        server.socket = context.wrap_socket(server.socket, server_side=True)

    protocol = "https" if cert_file else "http"
    print(json.dumps({"status": "started", "role": ROLE, "url": f"{protocol}://0.0.0.0:{PORT}"}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
