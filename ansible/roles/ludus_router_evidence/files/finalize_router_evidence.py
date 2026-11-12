#!/usr/bin/env python3
"""Seal a router PCAP manifest and spool enriched Zeek JSON for Vector."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
from datetime import datetime, timezone


def append_json_line(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(value, separators=(",", ":"), sort_keys=True) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def enrich_zeek_logs(
    input_dir: Path,
    spool_dir: Path,
    run_id: str,
    artifact_id: str,
    pcap_sha256: str,
    replay_id: str = "",
) -> tuple[list[str], int]:
    spool_dir.mkdir(parents=True, exist_ok=True)
    log_names: list[str] = []
    event_count = 0

    for source in sorted(input_dir.glob("*.log")):
        destination = spool_dir / source.name
        path_name = source.stem
        wrote = 0
        with source.open("r", encoding="utf-8") as reader, destination.open(
            "a", encoding="utf-8"
        ) as writer:
            for line_number, line in enumerate(reader, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"{source}:{line_number}: invalid Zeek JSON: {exc}") from exc
                if not isinstance(event, dict):
                    raise ValueError(f"{source}:{line_number}: Zeek record is not an object")
                event.setdefault("_path", path_name)
                event["run_id"] = run_id
                event["artifact_id"] = artifact_id
                event["pcap_sha256"] = pcap_sha256
                if replay_id:
                    event["replay_id"] = replay_id
                writer.write(json.dumps(event, separators=(",", ":"), sort_keys=True) + "\n")
                wrote += 1
            writer.flush()
            os.fsync(writer.fileno())
        if wrote:
            log_names.append(source.name)
            event_count += wrote

    if event_count == 0:
        raise ValueError("Zeek replay produced no JSON events")
    return log_names, event_count


def replay_existing(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="finalize_router_evidence.py replay")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--zeek-dir", type=Path, required=True)
    parser.add_argument("--zeek-spool-dir", type=Path, required=True)
    parser.add_argument("--artifact-spool", type=Path, required=True)
    parser.add_argument("--replay-id", required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    required = ("run_id", "artifact_id", "pcap_sha256")
    missing = [key for key in required if not manifest.get(key)]
    if missing:
        raise ValueError(f"manifest missing required fields: {', '.join(missing)}")

    log_names, event_count = enrich_zeek_logs(
        args.zeek_dir,
        args.zeek_spool_dir,
        manifest["run_id"],
        manifest["artifact_id"],
        manifest["pcap_sha256"],
        args.replay_id,
    )
    replay_manifest = dict(manifest)
    replay_manifest["replay_id"] = args.replay_id
    replay_manifest["replayed_at"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    replay_manifest["zeek_logs"] = log_names
    replay_manifest["zeek_log_count"] = len(log_names)
    replay_manifest["zeek_event_count"] = event_count
    append_json_line(args.artifact_spool, replay_manifest)
    print(json.dumps(replay_manifest, separators=(",", ":"), sort_keys=True))
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "replay":
        return replay_existing(sys.argv[2:])

    parser = argparse.ArgumentParser()
    parser.add_argument("--zeek-dir", type=Path, required=True)
    parser.add_argument("--zeek-spool-dir", type=Path, required=True)
    parser.add_argument("--artifact-spool", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--range-id", required=True)
    parser.add_argument("--source-host", required=True)
    parser.add_argument("--artifact-id", required=True)
    parser.add_argument("--pcap-path", required=True)
    parser.add_argument("--pcap-sha256", required=True)
    parser.add_argument("--capture-interface", required=True)
    parser.add_argument("--capture-filter", required=True)
    parser.add_argument("--started-at", required=True)
    parser.add_argument("--ended-at", required=True)
    parser.add_argument("--size-bytes", type=int, required=True)
    parser.add_argument("--packet-count", type=int, required=True)
    parser.add_argument("--zeek-version", required=True)
    args = parser.parse_args()

    log_names, event_count = enrich_zeek_logs(
        args.zeek_dir,
        args.zeek_spool_dir,
        args.run_id,
        args.artifact_id,
        args.pcap_sha256,
    )

    manifest = {
        "schema_version": 1,
        "artifact_type": "pcap",
        "artifact_id": args.artifact_id,
        "run_id": args.run_id,
        "range_id": args.range_id,
        "source_host": args.source_host,
        "event_time": args.ended_at,
        "started_at": args.started_at,
        "ended_at": args.ended_at,
        "capture_interface": args.capture_interface,
        "capture_filter": args.capture_filter,
        "pcap_path": args.pcap_path,
        "pcap_sha256": args.pcap_sha256,
        "size_bytes": args.size_bytes,
        "packet_count": args.packet_count,
        "zeek_version": args.zeek_version,
        "zeek_logs": log_names,
        "zeek_log_count": len(log_names),
        "zeek_event_count": event_count,
        "sealed": True,
    }

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.manifest.with_suffix(args.manifest.suffix + ".tmp")
    temporary.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.chmod(temporary, 0o600)
    temporary.replace(args.manifest)
    append_json_line(args.artifact_spool, manifest)
    print(json.dumps(manifest, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
