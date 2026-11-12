#!/usr/bin/env python3
"""Generate idempotent migration backfill INSERTs from materialized-view SQL."""

from __future__ import annotations

import argparse
import pathlib
import re

PATTERN = re.compile(
    r"CREATE\s+MATERIALIZED\s+VIEW\s+IF\s+NOT\s+EXISTS\s+\S+\s+TO\s+(?P<table>\S+)\s+AS\s*\n"
    r"(?P<select>(?:WITH|SELECT)\s+.*?\nWHERE\s+.*?);",
    re.IGNORECASE | re.DOTALL,
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("schema", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument(
        "--table",
        help="Generate only the projection targeting this fully qualified table",
    )
    args = parser.parse_args()

    source = args.schema.read_text(encoding="utf-8")
    all_matches = list(PATTERN.finditer(source))
    if len(all_matches) != 12:
        raise SystemExit(f"expected 12 source projections, found {len(all_matches)}")
    matches = [
        match
        for match in all_matches
        if args.table is None or match.group("table") == args.table
    ]
    if args.table is not None and len(matches) != 1:
        raise SystemExit(f"expected one projection for {args.table}, found {len(matches)}")

    chunks = [
        "-- Generated from vector-native.sql; do not edit by hand.",
        "-- Vector is stopped while these snapshots are inserted.",
        "",
    ]
    for match in matches:
        chunks.extend(
            [
                f"INSERT INTO {match.group('table')}",
                match.group("select").strip() + ";",
                "",
            ]
        )
    args.output.write_text("\n".join(chunks), encoding="utf-8")


if __name__ == "__main__":
    main()
