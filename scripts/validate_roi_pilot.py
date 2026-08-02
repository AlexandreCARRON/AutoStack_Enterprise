#!/usr/bin/env python3
"""Validate AutoStack's public AI ROI pilot without external dependencies."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path


ID_RE = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)*$")
EVIDENCE_LEVELS = {"measured", "calculated", "estimated", "declared"}
SCOPES = {"portfolio", "project", "capability", "execution"}
KPI_STATUSES = {"active", "proposed"}
AGGREGATIONS = {"sum", "weighted_mean", "ratio", "none"}
UNITS = {"EUR", "hours", "minutes", "ratio", "count", "score"}
SELECTION_KEYS = {
    "schema_version", "project_id", "pilot_status", "catalog_ref",
    "last_reviewed", "owner", "review_cadence", "privacy", "baseline",
    "selected_kpis", "excluded_kpis",
}
SELECTED_KPI_KEYS = {
    "id", "version", "status", "unit", "aggregation", "source", "target",
}
OBSERVATION_KEYS = {
    "observation_id", "kpi_id", "kpi_version", "scope_type", "scope_id",
    "period_start", "period_end", "value", "unit", "evidence_level",
    "source_refs", "sample_size", "numerator", "denominator", "benefit_id",
    "attribution_share", "recorded_at", "notes",
}


# Lit un fichier JSON-compatible YAML afin de conserver un validateur sans dépendance.
def load_selection(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


# Lit chaque observation indépendamment et refuse une ligne JSON partiellement valide.
def load_observations(path: Path) -> tuple[list[object], list[str]]:
    observations: list[object] = []
    errors: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            observations.append(json.loads(line))
        except json.JSONDecodeError as exc:
            errors.append(f"observations:{line_number}: JSON invalide ({exc.msg})")
    return observations, errors


# Valide les dates ISO sans inventer de valeur de remplacement.
def parse_date(value: object, label: str, errors: list[str]) -> date | None:
    try:
        return date.fromisoformat(str(value))
    except ValueError:
        errors.append(f"{label}: date ISO invalide")
        return None


# Signale les champs absents ou inconnus pour garder un contrat vérifiable.
def check_keys(value: dict[str, object], expected: set[str], label: str, errors: list[str]) -> None:
    missing = expected - value.keys()
    extra = value.keys() - expected
    if missing:
        errors.append(f"{label}: champs manquants ({', '.join(sorted(missing))})")
    if extra:
        errors.append(f"{label}: champs inconnus ({', '.join(sorted(extra))})")


# Contrôle la sélection, la limite de sept KPI et la protection du dépôt public.
def validate_selection(selection: object) -> tuple[list[str], dict[tuple[str, int], dict[str, object]]]:
    errors: list[str] = []
    index: dict[tuple[str, int], dict[str, object]] = {}
    if not isinstance(selection, dict):
        return ["selection: objet attendu"], index

    check_keys(selection, SELECTION_KEYS, "selection", errors)
    if selection.get("schema_version") != 1:
        errors.append("selection.schema_version: valeur attendue = 1")
    parse_date(selection.get("last_reviewed"), "selection.last_reviewed", errors)

    selected = selection.get("selected_kpis")
    if not isinstance(selected, list) or not selected:
        errors.append("selection.selected_kpis: liste non vide attendue")
        return errors, index
    if len(selected) > 7:
        errors.append("selection.selected_kpis: sept KPI maximum")

    for position, raw_kpi in enumerate(selected, 1):
        label = f"selected_kpis[{position}]"
        if not isinstance(raw_kpi, dict):
            errors.append(f"{label}: objet attendu")
            continue
        check_keys(raw_kpi, SELECTED_KPI_KEYS, label, errors)
        identifier = raw_kpi.get("id")
        version = raw_kpi.get("version")
        if not isinstance(identifier, str) or not ID_RE.fullmatch(identifier):
            errors.append(f"{label}.id: identifiant invalide")
        if not isinstance(version, int) or isinstance(version, bool) or version < 1:
            errors.append(f"{label}.version: entier positif attendu")
        if raw_kpi.get("status") not in KPI_STATUSES:
            errors.append(f"{label}.status: valeur invalide")
        if raw_kpi.get("unit") not in UNITS:
            errors.append(f"{label}.unit: valeur invalide")
        if raw_kpi.get("aggregation") not in AGGREGATIONS:
            errors.append(f"{label}.aggregation: valeur invalide")
        source = raw_kpi.get("source")
        if not isinstance(source, str) or len(source.strip()) < 8:
            errors.append(f"{label}.source: source absente ou trop courte")
        if isinstance(identifier, str) and isinstance(version, int):
            key = (identifier, version)
            if key in index:
                errors.append(f"{label}: KPI dupliqué {identifier}@{version}")
            else:
                index[key] = raw_kpi

    if selection.get("privacy") == "public-operational-only":
        forbidden = [key for key, kpi in index.items() if kpi.get("unit") == "EUR"]
        if forbidden:
            errors.append("selection: les KPI financiers sont interdits dans le pilote public")
    return errors, index


# Contrôle les références, preuves, ratios et unités de chaque observation immuable.
def validate_observations(
    observations: list[object],
    selected_index: dict[tuple[str, int], dict[str, object]],
    privacy: object,
) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for position, raw_observation in enumerate(observations, 1):
        label = f"observations[{position}]"
        if not isinstance(raw_observation, dict):
            errors.append(f"{label}: objet attendu")
            continue
        check_keys(raw_observation, OBSERVATION_KEYS, label, errors)

        observation_id = raw_observation.get("observation_id")
        if not isinstance(observation_id, str) or not ID_RE.fullmatch(observation_id):
            errors.append(f"{label}.observation_id: identifiant invalide")
        elif observation_id in seen:
            errors.append(f"{label}: observation dupliquée {observation_id}")
        else:
            seen.add(observation_id)

        kpi_id = raw_observation.get("kpi_id")
        kpi_version = raw_observation.get("kpi_version")
        reference = (str(kpi_id), kpi_version) if isinstance(kpi_version, int) else None
        kpi = selected_index.get(reference) if reference else None
        if kpi is None:
            errors.append(f"{label}: KPI absent de la sélection")
        elif raw_observation.get("unit") != kpi.get("unit"):
            errors.append(f"{label}.unit: unité différente de la sélection")

        value = raw_observation.get("value")
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            errors.append(f"{label}.value: nombre attendu")
        if raw_observation.get("scope_type") not in SCOPES:
            errors.append(f"{label}.scope_type: valeur invalide")
        evidence = raw_observation.get("evidence_level")
        if evidence not in EVIDENCE_LEVELS:
            errors.append(f"{label}.evidence_level: valeur invalide")
        sources = raw_observation.get("source_refs")
        if not isinstance(sources, list) or any(not isinstance(item, str) for item in sources):
            errors.append(f"{label}.source_refs: liste de chaînes attendue")
        elif evidence in {"measured", "calculated"} and not sources:
            errors.append(f"{label}.source_refs: source requise pour une preuve vérifiée")

        start = parse_date(raw_observation.get("period_start"), f"{label}.period_start", errors)
        end = parse_date(raw_observation.get("period_end"), f"{label}.period_end", errors)
        parse_date(raw_observation.get("recorded_at"), f"{label}.recorded_at", errors)
        if start and end and end < start:
            errors.append(f"{label}: period_end précède period_start")

        if kpi and kpi.get("aggregation") == "ratio":
            numerator = raw_observation.get("numerator")
            denominator = raw_observation.get("denominator")
            if not isinstance(numerator, (int, float)) or isinstance(numerator, bool):
                errors.append(f"{label}.numerator: nombre requis pour un ratio")
            if not isinstance(denominator, (int, float)) or isinstance(denominator, bool) or denominator <= 0:
                errors.append(f"{label}.denominator: nombre positif requis pour un ratio")
            if (
                isinstance(value, (int, float))
                and isinstance(numerator, (int, float))
                and isinstance(denominator, (int, float))
                and denominator > 0
                and abs(value - numerator / denominator) > 1e-9
            ):
                errors.append(f"{label}.value: ratio incohérent")

        if privacy == "public-operational-only" and raw_observation.get("unit") == "EUR":
            errors.append(f"{label}: mesure financière interdite dans le pilote public")
    return errors


# Exécute les contrôles ciblés et retourne un code stable pour GitHub Actions.
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("selection", type=Path)
    parser.add_argument("--observations", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        selection = load_selection(args.selection)
        observations, load_errors = load_observations(args.observations)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"ERROR: fichier illisible ({exc})")
        return 2

    selection_errors, selected_index = validate_selection(selection)
    privacy = selection.get("privacy") if isinstance(selection, dict) else None
    errors = load_errors + selection_errors + validate_observations(
        observations, selected_index, privacy
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"ROI pilot validation: OK ({len(selected_index)} KPI, {len(observations)} observation)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
