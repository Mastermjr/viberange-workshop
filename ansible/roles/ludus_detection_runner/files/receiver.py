#!/usr/bin/env python3
"""Minimal ClickDetect webhook receiver for the VibeRange workshop.

Accepts POSTed detection payloads, maps best-effort fields into ir.detections,
and inserts JSONEachRow into ClickHouse over HTTP.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import sys
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CLICKHOUSE_URL = os.environ.get("CLICKHOUSE_URL", "http://127.0.0.1:8123")
LISTEN = os.environ.get("LISTEN", "0.0.0.0")
PORT = int(os.environ.get("PORT", "9100"))


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")


def first(payload: dict, *keys: str, default=""):
    for key in keys:
        cur = payload
        ok = True
        for part in key.split("."):
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                ok = False
                break
        if ok and cur not in (None, ""):
            return cur
    return default


def normalize(payload: dict) -> dict:
    rows = first(payload, "matches", "rows", "data", default=[])
    if isinstance(rows, dict):
        rows = [rows]
    if not isinstance(rows, list):
        rows = []

    matched_event_ids = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        for key in ("event_id", "id", "uuid"):
            if row.get(key):
                matched_event_ids.append(str(row[key]))
                break
        for key in ("matched_event_ids", "event_ids"):
            values = row.get(key, [])
            if isinstance(values, list):
                matched_event_ids.extend(str(value) for value in values if value)

    matched_event_ids = list(dict.fromkeys(matched_event_ids))
    sample = rows[0] if rows and isinstance(rows[0], dict) else {}
    return {
        "time": first(payload, "time", "timestamp", "ts", default=now()),
        "rule_id": str(first(payload, "rule_id", "rule.id", "id", default="unknown")),
        "rule_name": str(first(payload, "rule_name", "rule.name", "name", default="unknown")),
        "severity": str(first(payload, "severity", "rule.severity", default="medium")),
        "matched_source": str(first(payload, "matched_source", "source", default=sample.get("source", sample.get("dataset", sample.get("source_type", "unknown"))))),
        "matched_host": str(first(payload, "matched_host", "host", "device_hostname", default=sample.get("source_host", sample.get("device_hostname", sample.get("host", ""))))),
        "experiment_run": str(first(payload, "experiment_run", default=sample.get("experiment_run", sample.get("run_id", "default")))),
        "matched_event_ids": matched_event_ids,
        "raw": json.dumps(payload, separators=(",", ":")),
    }


def insert_detection(row: dict):
    query = "INSERT INTO ir.detections FORMAT JSONEachRow"
    url = CLICKHOUSE_URL.rstrip("/") + "/?" + urllib.parse.urlencode(
        {"query": query, "date_time_input_format": "best_effort"}
    )
    body = (json.dumps(row, separators=(",", ":")) + "\n").encode()
    req = urllib.request.Request(url, data=body, method="POST")
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok\n")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path not in ("/detections", "/"):
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("content-length", "0"))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode())
            if isinstance(payload, list):
                count = 0
                for item in payload:
                    if isinstance(item, dict):
                        insert_detection(normalize(item))
                        count += 1
            elif isinstance(payload, dict):
                insert_detection(normalize(payload))
                count = 1
            else:
                raise ValueError("payload must be object or array")
        except Exception as exc:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(f"error: {exc}\n".encode())
            print(f"receiver error: {exc}", file=sys.stderr)
            return
        self.send_response(202)
        self.end_headers()
        self.wfile.write(f"accepted {count}\n".encode())

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} - {fmt % args}", file=sys.stderr)


if __name__ == "__main__":
    print(f"listening on {LISTEN}:{PORT}, clickhouse={CLICKHOUSE_URL}")
    ThreadingHTTPServer((LISTEN, PORT), Handler).serve_forever()
