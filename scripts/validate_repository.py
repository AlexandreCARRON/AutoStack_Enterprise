#!/usr/bin/env python3
"""Validate the repository contracts that should remain deterministic in CI."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

REQUIRED_DOCUMENTS = (
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "VERSIONS.md",
    "docs/README.md",
    "docs/governance.md",
)
DOCUMENT_DIRECTORIES = ("decisions", "docs", "measurement", "scripts", "tests")

ALLOWED_KINDS = {
    "fact",
    "source",
    "decision",
    "summary",
    "template",
    "deliverable",
    "policy",
    "standard",
    "task",
    "guide",
    "evaluation",
}
ALLOWED_STATUSES = {"draft", "active", "deprecated", "archived"}
ALLOWED_SENSITIVITY = {"public", "internal", "confidential", "restricted"}
SOURCE_REQUIRED_KINDS = {"fact", "source", "decision", "summary"}
LINK_RE = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
PRIVATE_KEY_RE = re.compile(
    rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
)


def parse_front_matter(path: Path) -> tuple[dict[str, object], list[str]]:
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as error:
        return {}, [f"{path}: lecture impossible ({error})"]

    if not lines or lines[0] != "---":
        return {}, [f"{path}: métadonnées YAML absentes"]

    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}, [f"{path}: bloc de métadonnées non fermé"]

    metadata: dict[str, object] = {}
    for line in lines[1:end]:
        if not line.strip():
            continue
        if ":" not in line:
            errors.append(f"{path}: ligne de métadonnées invalide: {line}")
            continue
        key, raw_value = line.split(":", 1)
        key = key.strip()
        value = raw_value.strip()
        if key == "sources":
            try:
                parsed = json.loads(value)
            except json.JSONDecodeError:
                errors.append(f"{path}: sources doit être une liste JSON sur une ligne")
                continue
            metadata[key] = parsed
        else:
            metadata[key] = value
    return metadata, errors


def validate_metadata(path: Path) -> tuple[str | None, list[str]]:
    metadata, errors = parse_front_matter(path)
    required = {"id", "kind", "status", "last_reviewed", "sensitivity", "sources"}
    missing = sorted(required - metadata.keys())
    if missing:
        errors.append(f"{path}: champs manquants: {', '.join(missing)}")
        return None, errors

    document_id = metadata["id"]
    if not isinstance(document_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", document_id):
        errors.append(f"{path}: id invalide")

    kind = metadata["kind"]
    if kind not in ALLOWED_KINDS:
        errors.append(f"{path}: kind invalide: {kind}")
    if metadata["status"] not in ALLOWED_STATUSES:
        errors.append(f"{path}: status invalide: {metadata['status']}")
    if metadata["sensitivity"] not in ALLOWED_SENSITIVITY:
        errors.append(f"{path}: sensitivity invalide: {metadata['sensitivity']}")

    try:
        date.fromisoformat(str(metadata["last_reviewed"]))
    except ValueError:
        errors.append(f"{path}: last_reviewed doit être une date ISO")

    sources = metadata["sources"]
    if not isinstance(sources, list) or not all(isinstance(item, str) for item in sources):
        errors.append(f"{path}: sources doit contenir uniquement des chaînes")
    elif kind in SOURCE_REQUIRED_KINDS and not sources:
        errors.append(f"{path}: une source est obligatoire pour kind={kind}")

    return document_id if isinstance(document_id, str) else None, errors


def validate_local_links(path: Path, root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    for raw_target in LINK_RE.findall(text):
        target = raw_target.strip().strip("<>").split("#", 1)[0]
        if not target or "://" in target or target.startswith(("mailto:", "/")):
            continue
        decoded = target.replace("%20", " ")
        resolved = (path.parent / decoded).resolve()
        try:
            resolved.relative_to(root.resolve())
        except ValueError:
            errors.append(f"{path}: lien hors dépôt: {raw_target}")
            continue
        if not resolved.exists():
            errors.append(f"{path}: lien local introuvable: {raw_target}")
    return errors


def validate_documents(root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    ids: dict[str, Path] = {}
    documents = {root / relative for relative in REQUIRED_DOCUMENTS}
    documents.update(path for path in root.glob("*.md") if path.name != "AGENTS.md")
    for directory in DOCUMENT_DIRECTORIES:
        documents.update((root / directory).glob("*.md"))

    for path in sorted(documents):
        if not path.is_file():
            errors.append(f"{path}: document maintenu absent")
            continue
        document_id, document_errors = validate_metadata(path)
        errors.extend(document_errors)
        errors.extend(validate_local_links(path, root))
        if document_id:
            if document_id in ids:
                errors.append(f"{path}: id dupliqué avec {ids[document_id]}: {document_id}")
            ids[document_id] = path
    return errors


def validate_default_versions(root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    service_roots: set[Path] = set()
    for compose in (root / "services").glob("*/*/docker-compose.yml"):
        service_roots.add(compose.parent.parent)
    for compose in (root / "services").glob("*/*/dockercompose.yml"):
        service_roots.add(compose.parent.parent)

    for service_root in sorted(service_roots):
        marker = service_root / "default-version"
        if not marker.is_file():
            errors.append(f"{service_root}: default-version absent")
            continue
        variant = marker.read_text(encoding="utf-8").strip()
        if not variant or "/" in variant or variant in {".", ".."}:
            errors.append(f"{marker}: nom de variante invalide")
            continue
        target = service_root / variant
        if not target.is_dir():
            errors.append(f"{marker}: variante introuvable: {variant}")
            continue
        compose_files = [target / "docker-compose.yml", target / "dockercompose.yml"]
        if not any(path.is_file() for path in compose_files):
            errors.append(f"{target}: fichier Compose absent")
        if not (target / ".env.example").is_file():
            errors.append(f"{target}: .env.example absent")
    return errors


def repository_files(root: Path = REPO_ROOT) -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return [root / item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def validate_secret_hygiene(root: Path = REPO_ROOT) -> list[str]:
    errors: list[str] = []
    for path in repository_files(root):
        relative = path.relative_to(root)
        name = path.name
        if name == ".env" or (name.startswith(".env.") and name != ".env.example"):
            errors.append(f"{relative}: fichier d'environnement privé versionné")
        if name.startswith("secret_") and path.suffix == ".txt":
            errors.append(f"{relative}: fichier de secret versionné")
        if path.suffix.lower() in {".pem", ".key"}:
            errors.append(f"{relative}: clé potentielle versionnée")
        try:
            content = path.read_bytes()
        except OSError as error:
            errors.append(f"{relative}: lecture impossible ({error})")
            continue
        if PRIVATE_KEY_RE.search(content):
            errors.append(f"{relative}: marqueur de clé privée détecté")
    return errors


def main() -> int:
    errors = [
        *validate_documents(),
        *validate_default_versions(),
        *validate_secret_hygiene(),
    ]
    if errors:
        print("Validation du dépôt: ECHEC")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        "Validation du dépôt: OK "
        "(documents maintenus, versions par défaut, hygiène des secrets)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
