#!/usr/bin/env python3
"""Génère les objets APISIX de démonstration depuis le classeur, sans dépendance Python externe."""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree as ET


MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"


def column_index(reference: str) -> int:
    match = re.match(r"([A-Z]+)", reference)
    if not match:
        raise ValueError(f"Référence de cellule XLSX invalide : {reference}")
    value = 0
    for char in match.group(1):
        value = value * 26 + ord(char) - ord("A") + 1
    return value - 1


def read_shared_strings(archive: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return ["".join(item.itertext()) for item in root.findall(f"{{{MAIN_NS}}}si")]


def workbook_sheet_paths(archive: zipfile.ZipFile) -> dict[str, str]:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {
        item.attrib["Id"]: item.attrib["Target"]
        for item in relationships.findall(f"{{{PKG_REL_NS}}}Relationship")
    }
    result: dict[str, str] = {}
    for sheet in workbook.findall(f".//{{{MAIN_NS}}}sheet"):
        target = targets[sheet.attrib[f"{{{REL_NS}}}id"]].lstrip("/")
        if not target.startswith("xl/"):
            target = str(PurePosixPath("xl") / target)
        result[sheet.attrib["name"]] = target.replace("xl/../", "")
    return result


def cell_text(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        inline = cell.find(f"{{{MAIN_NS}}}is")
        return "" if inline is None else "".join(inline.itertext())
    value = cell.find(f"{{{MAIN_NS}}}v")
    if value is None or value.text is None:
        return ""
    if cell_type == "s":
        return shared_strings[int(value.text)]
    if cell_type == "b":
        return "TRUE" if value.text == "1" else "FALSE"
    return value.text


def read_table(archive: zipfile.ZipFile, sheet_path: str, shared_strings: list[str]) -> list[dict[str, str]]:
    root = ET.fromstring(archive.read(sheet_path))
    rows: list[list[str]] = []
    for row in root.findall(f".//{{{MAIN_NS}}}row"):
        values: list[str] = []
        for cell in row.findall(f"{{{MAIN_NS}}}c"):
            index = column_index(cell.attrib["r"])
            while len(values) <= index:
                values.append("")
            values[index] = cell_text(cell, shared_strings).strip()
        if any(values):
            rows.append(values)
    if not rows:
        return []
    headers = rows[0]
    return [
        {header: values[index] if index < len(values) else "" for index, header in enumerate(headers)}
        for values in rows[1:]
    ]


def first_row(tables: dict[str, list[dict[str, str]]], name: str) -> dict[str, str]:
    rows = tables.get(name, [])
    if len(rows) != 1:
        raise ValueError(f"La feuille {name} doit contenir exactement une ligne de démonstration (trouvé : {len(rows)}).")
    return rows[0]


def enabled(value: str) -> bool:
    return value.strip().upper() in {"1", "TRUE", "YES", "Y", "OUI"}


def slug(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if not normalized:
        raise ValueError(f"Impossible de fabriquer un identifiant à partir de {value!r}")
    return normalized


def write_json(output_dir: Path, name: str, payload: object) -> None:
    target = output_dir / name
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Généré : {target}")


def generate(workbook: Path, output_dir: Path) -> None:
    required_sheets = {"PARTNER", "BACKEND", "UPSTREAM", "ROUTE", "SECURITY", "PLUGINS"}
    with zipfile.ZipFile(workbook) as archive:
        shared_strings = read_shared_strings(archive)
        sheet_paths = workbook_sheet_paths(archive)
        missing = required_sheets - sheet_paths.keys()
        if missing:
            raise ValueError(f"Feuilles manquantes : {', '.join(sorted(missing))}")
        tables = {
            name: read_table(archive, sheet_paths[name], shared_strings)
            for name in required_sheets
        }

    partner = first_row(tables, "PARTNER")
    backend = first_row(tables, "BACKEND")
    upstream_row = first_row(tables, "UPSTREAM")
    route_row = first_row(tables, "ROUTE")
    security = first_row(tables, "SECURITY")
    plugin_rows = tables["PLUGINS"]

    if security["AUTH_MODE"] != "key-auth":
        raise ValueError("Cette démo prend actuellement en charge AUTH_MODE=key-auth uniquement.")
    if backend["SCHEME"] != "https":
        raise ValueError("Le backend partenaire de la démo doit utiliser SCHEME=https.")
    if not re.fullmatch(r"[A-Za-z0-9.-]+", backend["HOST"]):
        raise ValueError("BACKEND.HOST doit être un nom DNS simple utilisable comme alias Docker.")
    if not enabled(security["MTLS"]):
        raise ValueError("La démo attend MTLS=TRUE afin de tester le certificat client APISIX.")

    consumer_id = partner["PARTNER_NAME"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", consumer_id):
        raise ValueError("PARTNER_NAME doit pouvoir servir d'identifiant de consommateur APISIX.")
    upstream_id = slug(upstream_row["UPSTREAM_NAME"])
    route_id = slug(route_row["ROUTE_NAME"])
    uri = route_row["URI"]
    uri_prefix = uri.removesuffix("*").rstrip("/")
    methods = [method.strip() for method in route_row["METHODS"].split("|") if method.strip()]
    port = int(backend["PORT"])
    if not 1 <= port <= 65535:
        raise ValueError("BACKEND.PORT doit être compris entre 1 et 65535.")

    plugins: dict[str, object] = {
        "key-auth": {"header": "X-API-Key", "hide_credentials": True},
        "proxy-rewrite": {
            "regex_uri": [f"^{re.escape(uri_prefix)}/?(.*)", "/$1"],
            "headers": {
                "set": {"X-Partner-Api-Key": "${DEMO_PARTNER_BACKEND_API_KEY}"}
            },
        },
    }
    for plugin_row in plugin_rows:
        if plugin_row.get("ROUTE") != route_row["ROUTE_NAME"] or not enabled(plugin_row.get("ENABLED", "")):
            continue
        plugin = plugin_row.get("PLUGIN")
        if plugin == "http-logger":
            plugins[plugin] = {
                "uri": "http://logstash:8080/apisix",
                "batch_max_size": 1,
                "inactive_timeout": 1,
            }
        else:
            raise ValueError(f"Plugin activé non pris en charge par la démo : {plugin}")

    upstream = {
        "id": upstream_id,
        "name": upstream_row["UPSTREAM_NAME"],
        "type": upstream_row["TYPE"],
        "retries": int(upstream_row["RETRIES"]),
        "scheme": backend["SCHEME"],
        "nodes": {f"{backend['HOST']}:{port}": 1},
        "labels": {"autostack-demo": "true", "partner-id": partner["PARTNER_ID"]},
    }
    route = {
        "id": route_id,
        "name": route_row["ROUTE_NAME"],
        "uri": uri,
        "methods": methods,
        "upstream_id": upstream_id,
        "plugins": plugins,
        "labels": {"autostack-demo": "true", "partner-id": partner["PARTNER_ID"]},
    }
    consumer = {
        "id": consumer_id,
        "username": partner["PARTNER_NAME"],
        "credential_id": slug(security["API_KEY_NAME"]),
        "credential": {"plugins": {"key-auth": {"key": "${DEMO_PARTNER_API_KEY}"}}},
        "labels": {"autostack-demo": "true", "environment": partner["ENVIRONMENT"]},
    }
    manifest = {
        "source": str(workbook),
        "partner": partner,
        "backend": backend,
        "security": security,
        "generated": ["upstream.json", "route.json", "plugins.json", "consumer.json"],
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    write_json(output_dir, "upstream.json", upstream)
    write_json(output_dir, "route.json", route)
    write_json(output_dir, "plugins.json", plugins)
    write_json(output_dir, "consumer.json", consumer)
    write_json(output_dir, "manifest.json", manifest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    try:
        generate(args.workbook, args.output_dir)
    except (KeyError, ValueError, zipfile.BadZipFile) as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
