#!/usr/bin/env python3
"""Create and transition explicit VibeRange experiment runs."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

RUN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
FACT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
ACTIVE_STATUSES = ("created", "running")
TERMINAL_STATUSES = ("completed", "failed", "aborted", "invalidated")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def generated_run_id() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"vr-{stamp}-{uuid.uuid4().hex[:8]}"


class ClickHouse:
    def __init__(self, executable: str):
        self.executable = executable

    def _run(self, query: str, *, params: dict[str, str] | None = None, body: str | None = None) -> str:
        command = [self.executable, "--query", query]
        for key, value in (params or {}).items():
            command.append(f"--param_{key}={value}")
        if body is not None:
            command.append("--date_time_input_format=best_effort")
        result = subprocess.run(
            command,
            input=body,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or f"ClickHouse exited {result.returncode}")
        return result.stdout

    def rows(self, query: str, params: dict[str, str] | None = None) -> list[dict]:
        output = self._run(query + " FORMAT JSONEachRow", params=params)
        return [json.loads(line) for line in output.splitlines() if line.strip()]

    def insert_event(self, row: dict) -> None:
        self._run(
            "INSERT INTO ir.experiment_run_events FORMAT JSONEachRow",
            body=json.dumps(row, separators=(",", ":")) + "\n",
        )


class RunControl:
    def __init__(self, config: dict):
        self.config = config
        self.base_dir = Path(config["base_dir"])
        self.ch = ClickHouse(config["clickhouse_client"])

    def require_synchronized_clock(self) -> None:
        if not self.config.get("require_ntp", True):
            return
        result = subprocess.run(
            [
                "timedatectl",
                "show",
                "--property=NTP",
                "--property=NTPSynchronized",
                "--value",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        clock_state = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if result.returncode or clock_state != ["yes", "yes"]:
            raise RuntimeError("analysis clock is not synchronized; run start refused")

    def get(self, run_id: str) -> dict:
        rows = self.ch.rows(
            "SELECT * FROM ir.experiment_runs WHERE run_id = {run_id:String}",
            {"run_id": run_id},
        )
        if len(rows) != 1:
            raise ValueError(f"run not found: {run_id}")
        return rows[0]

    def active(self) -> list[dict]:
        return self.ch.rows(
            "SELECT * FROM ir.experiment_runs "
            "WHERE range_id = {range_id:String} AND status IN ('created','running') "
            "ORDER BY created_at",
            {"range_id": self.config["range_id"]},
        )

    def list(self, limit: int) -> list[dict]:
        return self.ch.rows(
            "SELECT * FROM ir.experiment_runs WHERE range_id = {range_id:String} "
            f"ORDER BY created_at DESC LIMIT {int(limit)}",
            {"range_id": self.config["range_id"]},
        )

    def manifest_path(self, run_id: str) -> Path:
        return self.base_dir / run_id / "manifest.json"

    def write_manifest(self, state: dict, *, seal: bool = False) -> None:
        path = self.manifest_path(state["run_id"])
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        manifest = {
            "schema_version": 1,
            "run_id": state["run_id"],
            "range_id": state["range_id"],
            "scenario_id": state["scenario_id"],
            "scenario_version": state["scenario_version"],
            "blueprint_version": state["blueprint_version"],
            "source_ref": state["source_ref"],
            "operator": state["operator"],
            "status": state["status"],
            "created_at": state.get("created_at"),
            "started_at": state.get("started_at"),
            "ended_at": state.get("ended_at"),
            "caldera_operation_id": state.get("caldera_operation_id", ""),
            "adversary_id": state.get("adversary_id", ""),
            "notes": state.get("notes", ""),
        }
        temporary = path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.chmod(temporary, 0o600)
        temporary.replace(path)
        if seal:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            digest_path = path.with_suffix(".json.sha256")
            digest_path.write_text(f"{digest}  manifest.json\n", encoding="ascii")
            os.chmod(digest_path, 0o400)
            os.chmod(path, 0o400)

    def event_from_state(self, state: dict, status: str, **changes) -> dict:
        value = {
            "run_event_id": str(uuid.uuid4()),
            "run_id": state["run_id"],
            "recorded_at": utc_now(),
            "range_id": state["range_id"],
            "scenario_id": state["scenario_id"],
            "scenario_version": state["scenario_version"],
            "blueprint_version": state["blueprint_version"],
            "source_ref": state["source_ref"],
            "operator": state["operator"],
            "status": status,
            "started_at": state.get("started_at"),
            "ended_at": state.get("ended_at"),
            "caldera_operation_id": state.get("caldera_operation_id", ""),
            "adversary_id": state.get("adversary_id", ""),
            "manifest_path": str(self.manifest_path(state["run_id"])),
            "notes": state.get("notes", ""),
        }
        value.update(changes)
        return value

    def transition(self, run_id: str, allowed: tuple[str, ...], status: str, **changes) -> dict:
        state = self.get(run_id)
        if state["status"] not in allowed:
            raise ValueError(
                f"cannot transition {run_id} from {state['status']} to {status}; "
                f"expected {', '.join(allowed)}"
            )
        self.ch.insert_event(self.event_from_state(state, status, **changes))
        updated = self.get(run_id)
        self.write_manifest(updated, seal=updated["status"] in TERMINAL_STATUSES)
        return updated

    def create(self, args) -> dict:
        active = self.active()
        if active:
            raise ValueError(f"range already has active run: {active[0]['run_id']}")
        run_id = args.run_id or generated_run_id()
        validate_run_id(run_id)
        validate_fact("scenario ID", args.scenario_id)
        validate_fact("scenario version", args.scenario_version)
        operator = args.operator or os.environ.get("SUDO_USER") or os.environ.get("USER") or "unknown"
        now = utc_now()
        event = {
            "run_event_id": str(uuid.uuid4()),
            "run_id": run_id,
            "recorded_at": now,
            "range_id": self.config["range_id"],
            "scenario_id": args.scenario_id,
            "scenario_version": args.scenario_version,
            "blueprint_version": self.config["blueprint_version"],
            "source_ref": self.config["source_ref"],
            "operator": operator,
            "status": "created",
            "started_at": None,
            "ended_at": None,
            "caldera_operation_id": "",
            "adversary_id": "",
            "manifest_path": str(self.manifest_path(run_id)),
            "notes": args.notes or "",
        }
        self.ch.insert_event(event)
        state = self.get(run_id)
        self.write_manifest(state)
        return state


def validate_run_id(value: str) -> None:
    if not RUN_RE.fullmatch(value):
        raise ValueError("run ID must contain 1-64 letters, digits, underscores, or hyphens")


def validate_fact(name: str, value: str) -> None:
    if not FACT_RE.fullmatch(value):
        raise ValueError(f"{name} has unsupported characters or length")


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser()
    value.add_argument("--config", default="/etc/viberange-run-control.json")
    commands = value.add_subparsers(dest="command", required=True)

    create = commands.add_parser("create")
    create.add_argument("--run-id")
    create.add_argument("--scenario-id", required=True)
    create.add_argument("--scenario-version", required=True)
    create.add_argument("--operator")
    create.add_argument("--notes")

    start = commands.add_parser("start")
    start.add_argument("run_id")

    operation = commands.add_parser("set-operation")
    operation.add_argument("run_id")
    operation.add_argument("--operation-id", required=True)
    operation.add_argument("--adversary-id", required=True)

    complete = commands.add_parser("complete")
    complete.add_argument("run_id")
    complete.add_argument("--notes")

    for name in ("fail", "abort"):
        terminal = commands.add_parser(name)
        terminal.add_argument("run_id")
        terminal.add_argument("--notes", required=True)

    invalidate = commands.add_parser("invalidate")
    invalidate.add_argument("run_id")
    invalidate.add_argument("--notes", required=True)

    show = commands.add_parser("show")
    show.add_argument("run_id")

    listing = commands.add_parser("list")
    listing.add_argument("--limit", type=int, default=20)

    commands.add_parser("current")
    return value


def main() -> int:
    args = parser().parse_args()
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    control = RunControl(config)

    if args.command == "create":
        result = control.create(args)
    elif args.command == "start":
        validate_run_id(args.run_id)
        control.require_synchronized_clock()
        result = control.transition(args.run_id, ("created",), "running", started_at=utc_now())
    elif args.command == "set-operation":
        validate_run_id(args.run_id)
        validate_fact("operation ID", args.operation_id)
        validate_fact("adversary ID", args.adversary_id)
        current = control.get(args.run_id)
        result = control.transition(
            args.run_id,
            ("created", "running"),
            current["status"],
            caldera_operation_id=args.operation_id,
            adversary_id=args.adversary_id,
        )
    elif args.command == "complete":
        validate_run_id(args.run_id)
        changes = {"ended_at": utc_now()}
        if args.notes is not None:
            changes["notes"] = args.notes
        result = control.transition(args.run_id, ("running",), "completed", **changes)
    elif args.command in ("fail", "abort"):
        validate_run_id(args.run_id)
        result = control.transition(
            args.run_id,
            ACTIVE_STATUSES,
            "failed" if args.command == "fail" else "aborted",
            ended_at=utc_now(),
            notes=args.notes,
        )
    elif args.command == "invalidate":
        validate_run_id(args.run_id)
        result = control.transition(
            args.run_id,
            ("completed", "failed", "aborted"),
            "invalidated",
            notes=args.notes,
        )
    elif args.command == "show":
        validate_run_id(args.run_id)
        result = control.get(args.run_id)
    elif args.command == "list":
        result = control.list(args.limit)
    elif args.command == "current":
        result = control.active()
    else:
        raise AssertionError(args.command)

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(f"viberange-run: {exc}", file=sys.stderr)
        raise SystemExit(1)
