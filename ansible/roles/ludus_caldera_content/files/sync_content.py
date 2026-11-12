#!/usr/bin/env python3
"""Synchronize checked-in VibeRange YAML into Caldera's persistent object store."""

from __future__ import annotations

import glob
import json
from pathlib import Path
import sys

import requests
import yaml

BASE = Path("/opt/caldera")
PLUGIN = BASE / "plugins/viberange"
API = "http://127.0.0.1:8888/api/v2"


def api_key() -> str:
    for line in (BASE / "conf/default.yml").read_text(encoding="utf-8").splitlines():
        if line.lstrip().startswith("api_key_red:"):
            return line.split(":", 1)[1].strip().strip("'\"")
    raise RuntimeError("api_key_red is missing")


def put(session: requests.Session, route: str, payload: dict) -> None:
    response = session.put(f"{API}/{route}", json=payload, timeout=30)
    response.raise_for_status()


def ability_payload(entry: dict) -> dict:
    executors = []
    for platform, platform_executors in entry.get("platforms", {}).items():
        for name, executor in platform_executors.items():
            executors.append(
                {
                    "platform": platform,
                    "name": name,
                    "command": executor.get("command", ""),
                    "cleanup": executor.get("cleanup", []),
                    "payloads": executor.get("payloads", []),
                    "timeout": executor.get("timeout", 60),
                    "parsers": executor.get("parsers", []),
                }
            )
    technique = entry.get("technique", {})
    return {
        "name": entry["name"],
        "description": entry.get("description", ""),
        "tactic": entry["tactic"],
        "technique_id": technique.get("attack_id", ""),
        "technique_name": technique.get("name", ""),
        "executors": executors,
        "requirements": entry.get("requirements", []),
        "repeatable": entry.get("repeatable", False),
        "singleton": entry.get("singleton", False),
    }


def main() -> int:
    session = requests.Session()
    session.headers.update({"KEY": api_key(), "Content-Type": "application/json"})
    ability_ids = []
    for filename in sorted(glob.glob(str(PLUGIN / "data/abilities/**/*.yml"), recursive=True)):
        entries = yaml.safe_load(Path(filename).read_text(encoding="utf-8")) or []
        for entry in entries:
            ability_id = entry["id"]
            put(session, f"abilities/{ability_id}", ability_payload(entry))
            ability_ids.append(ability_id)
    adversary_ids = []
    for filename in sorted(glob.glob(str(PLUGIN / "data/adversaries/*.yml"))):
        entry = yaml.safe_load(Path(filename).read_text(encoding="utf-8"))
        adversary_id = entry["id"]
        put(
            session,
            f"adversaries/{adversary_id}",
            {
                "name": entry["name"],
                "description": entry.get("description", ""),
                "atomic_ordering": entry["atomic_ordering"],
            },
        )
        adversary_ids.append(adversary_id)
    print(json.dumps({"abilities": len(ability_ids), "adversaries": adversary_ids}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, requests.RequestException, yaml.YAMLError) as exc:
        print(f"sync_content: {exc}", file=sys.stderr)
        raise SystemExit(1)
