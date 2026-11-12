#!/usr/bin/env python3
"""Idempotently seed shared VibeRange CH-UI searches and dashboard content."""

from __future__ import annotations

import argparse
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.request


def fail(message: str) -> None:
    print(f"CH-UI seed failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--dashboard", required=True)
    parser.add_argument("--username", required=True)
    args = parser.parse_args()

    password = os.environ.get("CHUI_BOOTSTRAP_PASSWORD", "")
    base = args.url.rstrip("/")
    cookies = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))

    def request(method: str, path: str, body: object | None = None) -> object:
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(
            base + path,
            data=data,
            method=method,
            headers={"Accept": "application/json", "Content-Type": "application/json"},
        )
        try:
            with opener.open(req, timeout=30) as response:
                payload = response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")
            fail(f"{method} {path}: HTTP {exc.code}: {detail[:1000]}")
        except Exception as exc:
            fail(f"{method} {path}: {exc}")
        if not payload:
            return {}
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            fail(f"{method} {path}: invalid JSON response")

    connections = request("GET", "/api/auth/connections")
    available = connections.get("connections", [])
    if len(available) != 1:
        fail(f"expected exactly one connection, found {len(available)}")
    connection_id = available[0]["id"]

    request(
        "POST",
        "/api/auth/login",
        {"username": args.username, "password": password, "connection_id": connection_id},
    )

    with open(args.catalog, encoding="utf-8") as stream:
        catalog = json.load(stream)
    with open(args.dashboard, encoding="utf-8") as stream:
        dashboard_spec = json.load(stream)

    folder_name = f"VibeRange {catalog['range_id']}"
    folders = request("GET", "/api/saved-queries/folders").get("folders", [])
    folder = next((item for item in folders if item.get("name") == folder_name), None)
    if folder is None:
        folder = request("POST", "/api/saved-queries/folders", {"name": folder_name})
    folder_id = folder.get("id") or folder.get("folder", {}).get("id")
    if not folder_id:
        fail("saved-query folder response contained no id")

    current = request("GET", "/api/saved-queries/?scope=all").get("saved_queries", [])
    by_name = {item["name"]: item for item in current}
    created_queries = 0
    updated_queries = 0
    for definition in catalog["saved_queries"]:
        body = {
            "name": definition["name"],
            "description": definition.get("description", ""),
            "query": definition["query"],
            "connection_id": connection_id,
            "verified": True,
            "folder_id": folder_id,
            "tags": definition.get("tags", []),
            "visibility": "shared",
        }
        existing = by_name.get(definition["name"])
        if existing is None:
            request("POST", "/api/saved-queries/", body)
            created_queries += 1
            continue
        unchanged = (
            existing.get("description", "") == body["description"]
            and existing.get("query") == body["query"]
            and existing.get("connection_id") == connection_id
            and existing.get("verified") is True
            and existing.get("folder_id") == folder_id
            and sorted(existing.get("tags", [])) == sorted(body["tags"])
            and existing.get("visibility") == "shared"
        )
        if unchanged:
            continue
        body["if_version"] = existing.get("version", 0)
        request("PUT", f"/api/saved-queries/{existing['id']}", body)
        updated_queries += 1

    dashboard_name = dashboard_spec["dashboard"]["name"]
    dashboards = request("GET", "/api/dashboards/").get("dashboards", [])
    existing_dashboard = next((item for item in dashboards if item.get("name") == dashboard_name), None)
    dashboard_created = False
    if existing_dashboard is None:
        created = request(
            "POST",
            "/api/dashboards/",
            {
                "name": dashboard_name,
                "description": dashboard_spec["dashboard"].get("description", ""),
                "tags": ["viberange", "live-evidence"],
            },
        )
        existing_dashboard = created.get("dashboard", created)
        dashboard_created = True
    dashboard_id = existing_dashboard.get("id")
    if not dashboard_id:
        fail("dashboard response contained no id")

    for panel in dashboard_spec["panels"]:
        panel["connection_id"] = connection_id

    detail = request("GET", f"/api/dashboards/{dashboard_id}/")

    def panel_signature(panel: dict) -> tuple:
        config = panel.get("config", {})
        if isinstance(config, str):
            try:
                config = json.loads(config)
            except json.JSONDecodeError:
                pass
        return (
            panel.get("name", ""),
            panel.get("description", ""),
            panel.get("panel_type", "table"),
            panel.get("query", ""),
            panel.get("connection_id") or "",
            json.dumps(config, sort_keys=True),
            panel.get("layout_x", 0),
            panel.get("layout_y", 0),
            panel.get("layout_w", 6),
            panel.get("layout_h", 4),
        )

    dashboard_updated = dashboard_created or (
        detail.get("dashboard", {}).get("description", "")
        != dashboard_spec["dashboard"].get("description", "")
        or [panel_signature(p) for p in detail.get("panels", [])]
        != [panel_signature(p) for p in dashboard_spec["panels"]]
    )
    if dashboard_updated:
        request("POST", f"/api/dashboards/{dashboard_id}/import", dashboard_spec)

    verify_queries = request("GET", "/api/saved-queries/?scope=all").get("saved_queries", [])
    verify_dashboard = request("GET", f"/api/dashboards/{dashboard_id}/")
    expected_names = {item["name"] for item in catalog["saved_queries"]}
    actual_names = {item["name"] for item in verify_queries}
    missing = sorted(expected_names - actual_names)
    if missing:
        fail(f"saved queries missing after seed: {missing}")
    panel_count = len(verify_dashboard.get("panels", []))
    if panel_count != len(dashboard_spec["panels"]):
        fail(f"dashboard has {panel_count} panels, expected {len(dashboard_spec['panels'])}")

    print(
        json.dumps(
            {
                "catalog_version": catalog["catalog_version"],
                "saved_queries": len(expected_names),
                "created": created_queries,
                "updated": updated_queries,
                "dashboard": dashboard_name,
                "dashboard_updated": dashboard_updated,
                "panels": panel_count,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
