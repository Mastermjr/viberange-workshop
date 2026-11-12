#!/usr/bin/env python3
"""Participant-facing orchestration for one bounded VibeRange experiment."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from typing import Any
import urllib.error
import urllib.request
import uuid

FACT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
RUN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")


def command(argv: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"command failed: {argv[0]}")
    return result


def json_command(argv: list[str]) -> Any:
    result = command(argv)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid JSON from {argv[0]}: {exc}") from exc


class Experiment:
    def __init__(self, config: dict[str, Any]):
        self.config = config
        self.run_control = config["run_control_command"]

    def require_root(self) -> None:
        if os.geteuid() != 0:
            raise RuntimeError("run with sudo on the assigned clickhouse-ir VM")

    def run_cli(self, *args: str) -> Any:
        return json_command([self.run_control, *args])

    def active(self) -> list[dict[str, Any]]:
        result = self.run_cli("current")
        if not isinstance(result, list):
            raise RuntimeError("run-control current response is not a list")
        return result

    def one_active(self) -> dict[str, Any]:
        active = self.active()
        if len(active) != 1:
            raise RuntimeError(f"expected one active run, found {len(active)}")
        return active[0]

    def router(self, action: str, run_id: str | None = None) -> Any:
        remote = action if run_id is None else f"{action} {run_id}"
        argv = [
            "ssh",
            "-i",
            self.config["router_identity_file"],
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            "-p",
            str(self.config["router_port"]),
            "-o",
            f"UserKnownHostsFile={self.config['router_known_hosts']}",
            "-o",
            "StrictHostKeyChecking=yes",
            f"{self.config['router_user']}@{self.config['router_host']}",
            remote,
        ]
        return json_command(argv)

    def hook(self, phase: str, run_id: str, scenario_id: str) -> dict[str, Any]:
        path = self.config.get(f"{phase}_hook", "")
        if not path or not Path(path).is_file() or not os.access(path, os.X_OK):
            return {"state": "not_configured", "phase": phase}
        result = command([path, run_id, scenario_id])
        if not result.stdout.strip():
            return {"state": "completed", "phase": phase}
        try:
            value = json.loads(result.stdout)
        except json.JSONDecodeError:
            value = {"state": "completed", "phase": phase, "message": result.stdout.strip()}
        return value

    def caldera_request(self, method: str, route: str, body: object | None = None) -> Any:
        data = None if body is None else json.dumps(body).encode("utf-8")
        request = urllib.request.Request(
            self.config["caldera_url"].rstrip("/") + "/api/v2/" + route.lstrip("/"),
            data=data,
            method=method,
            headers={"KEY": self.config["caldera_api_key"], "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Caldera {method} {route} failed: HTTP {exc.code}: {detail[:300]}") from exc
        return json.loads(payload) if payload else {}

    def set_caldera_run_fact(self, run_id: str) -> str:
        base_source_id = self.config["caldera_source_id"]
        source = self.caldera_request("GET", f"sources/{base_source_id}")
        facts = []
        observed_run_fact = False
        for fact in source.get("facts", []):
            trait = fact.get("trait", "")
            value = run_id if trait == "viberange.run.id" else str(fact.get("value", ""))
            observed_run_fact = observed_run_fact or trait == "viberange.run.id"
            facts.append({"trait": trait, "value": value})
        if not observed_run_fact:
            raise RuntimeError("Caldera VibeRange source has no viberange.run.id fact")
        run_source_id = str(uuid.uuid5(uuid.UUID(base_source_id), run_id))
        try:
            verify = self.caldera_request("GET", f"sources/{run_source_id}")
        except RuntimeError as exc:
            if "HTTP 404" not in str(exc):
                raise
            verify = self.caldera_request(
                "POST",
                "sources",
                {
                    "id": run_source_id,
                    "name": f"VibeRange facts {run_id}",
                    "facts": facts,
                    "rules": [],
                    "relationships": [],
                    "adjustments": [],
                },
            )
        values = [f.get("value") for f in verify.get("facts", []) if f.get("trait") == "viberange.run.id"]
        if values != [run_id]:
            raise RuntimeError("Caldera run-specific source did not contain the experiment run ID")
        return run_source_id

    def atomic_write_jsonl(self, path: Path, rows: list[dict[str, Any]]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
                for row in rows:
                    stream.write(json.dumps(row, separators=(",", ":"), sort_keys=True) + "\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temporary, 0o640)
            os.replace(temporary, path)
        except Exception:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            raise

    def export_caldera(
        self,
        run_id: str,
        operation_id: str,
        operation: dict[str, Any],
        links: list[dict[str, Any]],
    ) -> None:
        exported_operation = dict(operation)
        exported_operation["run_id"] = run_id
        exported_links = []
        for raw_link in links:
            link = dict(raw_link)
            link["operation_id"] = operation_id
            link["run_id"] = run_id
            if link.get("output") == "True" and link.get("id"):
                result = self.caldera_request("GET", f"operations/{operation_id}/links/{link['id']}/result")
                encoded = result.get("result", "")
                if encoded:
                    link["output"] = base64.b64decode(encoded).decode("utf-8", errors="replace")
            exported_links.append(link)
        spool = Path(self.config["caldera_spool_dir"])
        self.atomic_write_jsonl(spool / f"{operation_id}.operation.jsonl", [exported_operation])
        self.atomic_write_jsonl(spool / f"{operation_id}.links.jsonl", exported_links)

    def run_caldera(self, run_id: str, scenario_id: str) -> dict[str, Any]:
        if scenario_id != "k8s-goat-attack":
            raise RuntimeError(f"unsupported prepared Caldera scenario: {scenario_id}")
        run_source_id = self.set_caldera_run_fact(run_id)
        agents = self.caldera_request("GET", "agents")
        if not any(agent.get("group") == self.config["caldera_group"] for agent in agents):
            raise RuntimeError("no active Caldera agent in the prepared group")
        planners = self.caldera_request("GET", "planners")
        planner_id = next((p.get("id") for p in planners if p.get("name") == "atomic"), "")
        if not planner_id:
            raise RuntimeError("Caldera atomic planner is unavailable")
        operation = self.caldera_request(
            "POST",
            "operations",
            {
                "name": f"k8s-goat-attack {run_id}",
                "adversary": {"adversary_id": self.config["caldera_adversary_id"]},
                "planner": {"id": planner_id},
                "source": {"id": run_source_id},
                "group": self.config["caldera_group"],
            },
        )
        operation_id = operation.get("id", "")
        if not operation_id:
            raise RuntimeError("Caldera operation response contained no ID")
        deadline = time.monotonic() + 900
        while time.monotonic() < deadline:
            operation = self.caldera_request("GET", f"operations/{operation_id}")
            if operation.get("state") in ("finished", "out_of_time"):
                break
            time.sleep(5)
        else:
            raise RuntimeError(f"Caldera operation {operation_id} did not finish within 900 seconds")
        links = self.caldera_request("GET", f"operations/{operation_id}/links")
        expected = set(self.config["caldera_expected_abilities"])
        observed = {(link.get("ability") or {}).get("ability_id") for link in links}
        failed = [link.get("id", "unknown") for link in links if str(link.get("status")) != "0"]
        self.export_caldera(run_id, operation_id, operation, links)
        if operation.get("state") != "finished" or expected != observed or failed:
            raise RuntimeError(
                f"Caldera operation validation failed: state={operation.get('state')} "
                f"missing={sorted(expected - observed)} unexpected={sorted(observed - expected)} failed_links={failed}"
            )
        return {
            "state": "finished",
            "operation_id": operation_id,
            "adversary_id": self.config["caldera_adversary_id"],
            "links": len(links),
        }

    def start(self, args: argparse.Namespace) -> dict[str, Any]:
        validate_fact("scenario ID", args.scenario)
        validate_fact("scenario version", args.scenario_version)
        if args.run_id:
            validate_run_id(args.run_id)
        create_argv = [
            "create",
            "--scenario-id",
            args.scenario,
            "--scenario-version",
            args.scenario_version,
            "--operator",
            args.operator or os.environ.get("SUDO_USER") or os.environ.get("USER") or "participant",
        ]
        if args.run_id:
            create_argv.extend(["--run-id", args.run_id])
        created = self.run_cli(*create_argv)
        run_id = created["run_id"]
        self.run_cli("start", run_id)
        try:
            capture = self.router("start", run_id)
        except Exception:
            self.run_cli("abort", run_id, "--notes", "router capture failed during experiment start")
            raise
        try:
            attack = self.run_caldera(run_id, args.scenario)
            self.run_cli(
                "set-operation",
                run_id,
                "--operation-id",
                attack["operation_id"],
                "--adversary-id",
                attack["adversary_id"],
            )
        except Exception:
            try:
                self.router("stop", run_id)
            finally:
                self.run_cli("abort", run_id, "--notes", "prepared Caldera operation failed during experiment start")
            raise
        return {"run_id": run_id, "status": "running", "capture": capture, "attack": attack}

    def status(self) -> dict[str, Any]:
        active = self.active()
        router = self.router("status")
        return {"active_runs": active, "router": router}

    def stop(self, notes: str | None) -> dict[str, Any]:
        current = self.one_active()
        if current["status"] != "running":
            raise RuntimeError(f"active run is {current['status']}, expected running")
        run_id = current["run_id"]
        attack = self.hook("stop", run_id, current["scenario_id"])
        capture = self.router("stop", run_id)
        argv = ["complete", run_id]
        if notes:
            argv.extend(["--notes", notes])
        completed = self.run_cli(*argv)
        return {"run_id": run_id, "status": completed["status"], "capture": capture, "attack": attack}

    def abort(self, reason: str) -> dict[str, Any]:
        current = self.one_active()
        run_id = current["run_id"]
        attack = self.hook("abort", run_id, current["scenario_id"])
        capture_result: Any
        try:
            capture_result = self.router("stop", run_id) if current["status"] == "running" else self.router("status")
        except Exception as exc:
            capture_result = {"state": "error", "message": str(exc)}
        aborted = self.run_cli("abort", run_id, "--notes", reason)
        return {"run_id": run_id, "status": aborted["status"], "capture": capture_result, "attack": attack}


def validate_fact(name: str, value: str) -> None:
    if not FACT_RE.fullmatch(value):
        raise ValueError(f"{name} has unsupported characters or length")


def validate_run_id(value: str) -> None:
    if not RUN_RE.fullmatch(value):
        raise ValueError("run ID must contain 1-64 letters, digits, underscores, or hyphens")


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(prog="viberange-experiment")
    value.add_argument("--config", default="/etc/viberange-experiment/config.json")
    commands = value.add_subparsers(dest="command", required=True)

    start = commands.add_parser("start", help="start one bounded prepared experiment")
    start.add_argument("scenario")
    start.add_argument("--scenario-version", default="1.0.0")
    start.add_argument("--run-id")
    start.add_argument("--operator")

    commands.add_parser("status", help="show active run and router capture state")

    stop = commands.add_parser("stop", help="seal evidence and complete the active run")
    stop.add_argument("--notes")

    abort = commands.add_parser("abort", help="seal available evidence and abort the active run")
    abort.add_argument("--reason", required=True)
    return value


def main() -> int:
    args = parser().parse_args()
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    experiment = Experiment(config)
    experiment.require_root()
    if args.command == "start":
        result = experiment.start(args)
    elif args.command == "status":
        result = experiment.status()
    elif args.command == "stop":
        result = experiment.stop(args.notes)
    elif args.command == "abort":
        result = experiment.abort(args.reason)
    else:
        raise AssertionError(args.command)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"viberange-experiment: {exc}", file=sys.stderr)
        raise SystemExit(1)
