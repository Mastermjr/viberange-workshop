#!/usr/bin/env python3
"""Validate the participant CH-UI session without printing credentials."""

from __future__ import annotations

import argparse
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.request


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--range-id", required=True)
    args = parser.parse_args()
    password = os.environ.get("CHUI_READER_PASSWORD", "")
    base = args.url.rstrip("/")
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def call(method: str, path: str, body=None, expected=200):
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            base + path,
            data=data,
            method=method,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        try:
            with opener.open(request, timeout=30) as response:
                if response.status != expected:
                    raise RuntimeError(f"{method} {path}: HTTP {response.status}, expected {expected}")
                payload = response.read()
        except urllib.error.HTTPError as exc:
            if exc.code == expected:
                return {"status": exc.code}
            detail = exc.read().decode(errors="replace")
            raise RuntimeError(f"{method} {path}: HTTP {exc.code}: {detail[:500]}") from exc
        return json.loads(payload) if payload else {}

    connections = call("GET", "/api/auth/connections")["connections"]
    if len(connections) != 1:
        raise RuntimeError(f"expected one connection, found {len(connections)}")
    login = call(
        "POST",
        "/api/auth/login",
        {
            "username": args.username,
            "password": password,
            "connection_id": connections[0]["id"],
        },
    )
    if login.get("user_role") != "viewer":
        raise RuntimeError(f"participant CH-UI role is {login.get('user_role')!r}, expected 'viewer'")

    queries = call("GET", "/api/saved-queries/?scope=all").get("saved_queries", [])
    if len(queries) < 12 or not all(item.get("verified") for item in queries if item.get("name", "").startswith(tuple("0123456789"))):
        raise RuntimeError("participant cannot see the complete verified VibeRange query catalog")

    dashboard_name = f"VibeRange Live Evidence — {args.range_id}"
    dashboards = call("GET", "/api/dashboards/").get("dashboards", [])
    matching_dashboards = [item for item in dashboards if item.get("name") == dashboard_name]
    if not matching_dashboards:
        raise RuntimeError("participant cannot see the VibeRange live-evidence dashboard")
    dashboard = call("GET", f"/api/dashboards/{matching_dashboards[0]['id']}/")
    tetragon_panels = [
        panel
        for panel in dashboard.get("panels", [])
        if panel.get("name") == "Recent Tetragon runtime activity"
    ]
    if len(tetragon_panels) != 1:
        raise RuntimeError("expected one Tetragon runtime dashboard panel")
    tetragon_result = call(
        "POST",
        "/api/dashboards/query",
        {"query": tetragon_panels[0]["query"]},
    )
    if not tetragon_result.get("success"):
        raise RuntimeError("Tetragon runtime dashboard query failed")

    proof_name = f"VibeRange Kubernetes Telemetry Proof — {args.range_id}"
    proof_matches = [item for item in dashboards if item.get("name") == proof_name]
    if not proof_matches:
        raise RuntimeError("participant cannot see the Kubernetes telemetry proof dashboard")
    proof_dashboard = call("GET", f"/api/dashboards/{proof_matches[0]['id']}/")
    proof_panels = proof_dashboard.get("panels", [])
    if len(proof_panels) != 9:
        raise RuntimeError(f"telemetry proof dashboard has {len(proof_panels)} panels, expected 9")
    for panel in proof_panels:
        panel_result = call(
            "POST",
            "/api/dashboards/query",
            {"query": panel["query"]},
        )
        if not panel_result.get("success"):
            raise RuntimeError(f"telemetry proof panel failed: {panel.get('name')}")

    all_workloads_name = f"VibeRange Kubernetes Telemetry — {args.range_id} (All Workloads)"
    all_workloads_matches = [item for item in dashboards if item.get("name") == all_workloads_name]
    if not all_workloads_matches:
        raise RuntimeError("participant cannot see the all-workload Kubernetes telemetry dashboard")
    all_workloads_dashboard = call("GET", f"/api/dashboards/{all_workloads_matches[0]['id']}/")
    all_workloads_panels = all_workloads_dashboard.get("panels", [])
    if len(all_workloads_panels) != 9:
        raise RuntimeError(
            f"all-workload telemetry dashboard has {len(all_workloads_panels)} panels, expected 9"
        )
    for panel in all_workloads_panels:
        panel_result = call(
            "POST",
            "/api/dashboards/query",
            {"query": panel["query"]},
        )
        if not panel_result.get("success"):
            raise RuntimeError(f"all-workload telemetry panel failed: {panel.get('name')}")

    result = call(
        "POST",
        "/api/dashboards/query",
        {"query": f"SELECT count() AS events FROM ir.raw_events WHERE range_id = '{args.range_id}'"},
    )
    if not result.get("success") or not result.get("data"):
        raise RuntimeError("participant dashboard query returned no result")

    call(
        "POST",
        "/api/saved-queries/",
        {"name": "must-not-create", "query": "SELECT 1"},
        expected=403,
    )
    print(json.dumps({"role": "viewer", "saved_queries": len(queries), "dashboard": dashboard_name, "dashboard_panels": len(dashboard.get("panels", [])), "tetragon_panel": "ok", "proof_dashboard": proof_name, "proof_panels": len(proof_panels), "all_workloads_dashboard": all_workloads_name, "all_workloads_panels": len(all_workloads_panels), "read_query": "ok", "write_api": "denied"}, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"CH-UI participant validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
