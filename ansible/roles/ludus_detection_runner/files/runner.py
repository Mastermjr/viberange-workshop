#!/usr/bin/env python3
import hashlib
import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

CLICKHOUSE = os.environ.get("CLICKHOUSE_URL", "http://127.0.0.1:8123")
RECEIVER = os.environ.get("RECEIVER_URL", "http://127.0.0.1:9100/detections")
RULES = Path(os.environ.get("RULES_DIR", "/opt/viberange-detection/rules"))
STATE = Path(os.environ.get("STATE_FILE", "/var/lib/viberange-detection/state.json"))
INTERVAL = int(os.environ.get("INTERVAL", "30"))


def query(sql):
    sql = sql.strip().rstrip(";") + " FORMAT JSON"
    req = urllib.request.Request(CLICKHOUSE.rstrip("/") + "/", data=sql.encode(), method="POST")
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response).get("data", [])


def post(payload):
    req = urllib.request.Request(RECEIVER, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=10) as response:
        return response.status


def load_seen():
    try: return set(json.loads(STATE.read_text()).get("seen", []))
    except Exception: return set()


def save_seen(seen):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"seen": list(seen)[-5000:]}, indent=2))
    tmp.replace(STATE)


def canonicalize(value):
    """Return a stable representation for set-like ClickHouse results."""
    if isinstance(value, dict):
        return {key: canonicalize(value[key]) for key in sorted(value)}
    if isinstance(value, list):
        items = [canonicalize(item) for item in value]
        return sorted(items, key=lambda item: json.dumps(item, sort_keys=True, default=str))
    return value


def run_once(seen):
    for path in sorted(RULES.glob("*.yml")):
        rule = yaml.safe_load(path.read_text())
        rows = query(rule["query"])
        if len(rows) < int(rule.get("threshold", 1)):
            continue
        # ClickHouse does not guarantee row or grouped-array order unless every
        # query supplies a total ordering. Canonicalize matches so the same
        # evidence set cannot emit duplicate detections on later scheduler runs.
        rows = canonicalize(rows)
        rule_id = path.stem
        fingerprint = hashlib.sha256((rule_id + json.dumps(rows, sort_keys=True, default=str)).encode()).hexdigest()
        if fingerprint in seen:
            continue
        payload = {
            "rule_id": rule_id,
            "rule_name": rule.get("name", rule_id),
            "severity": rule.get("severity", "medium"),
            "matches": rows,
            "experiment_run": rows[0].get("experiment_run", rows[0].get("run_id", "default")) if rows else "default",
        }
        post(payload)
        seen.add(fingerprint)
        print(f"detection rule={rule_id} matches={len(rows)}", flush=True)
    save_seen(seen)


if __name__ == "__main__":
    seen = load_seen()
    while True:
        try: run_once(seen)
        except Exception as exc: print(f"runner error: {exc}", flush=True)
        time.sleep(INTERVAL)
