# `ludus_run_control`

Defines explicit experiment boundaries without redeploying the range or
restarting telemetry agents. It installs an append-only ClickHouse run ledger,
a current-state view, query-time raw-event membership, evidence-count views,
and a root-operated CLI on the analysis VM.

## Lifecycle

```bash
sudo viberange-run create \
  --scenario-id goat-network-proof \
  --scenario-version 1.0.0

sudo viberange-run start RUN_ID
sudo viberange-run set-operation RUN_ID \
  --operation-id CALDERA_OPERATION_ID \
  --adversary-id ADVERSARY_ID
sudo viberange-run complete RUN_ID
```

Use `fail` or `abort` with a required note when a run does not complete. Use
`invalidate` when a terminal run later fails an integrity check. Only one
`created` or `running` run may exist per range, and `start` refuses to establish
a measured boundary unless the analysis clock reports NTP synchronization.

The controller writes an immutable transition row for every state change and a
root-only JSON manifest under `/var/lib/viberange-runs/RUN_ID/`. Terminal
manifests are read-only and receive a SHA-256 sidecar.

## Evidence membership

`ir.raw_events_by_run` associates evidence by `range_id` and the explicit
`started_at`/`ended_at` boundary. This is intentionally a visible
`range_time_window` rule. Sources with stronger identifiers retain those IDs in
native fields or raw data, including Caldera operation/link IDs and router
`run_id`/`artifact_id` values.

This model keeps preflight and post-run reconciliation outside the measured
window and avoids changing long-running Vector agent configuration for every
experiment.

## Router orchestration

The run controller establishes identity and time bounds. The experiment driver
uses the same ID with router evidence:

```bash
sudo viberange-run start RUN_ID
# on the router
sudo viberange-router-evidence start RUN_ID
# execute scenario
sudo viberange-router-evidence stop RUN_ID
# on the analysis VM
sudo viberange-run complete RUN_ID
```

The PCAP manifest provides explicit artifact membership; host/runtime/control-
plane sources initially use the bounded run window. Deterministic correlation
views can state stronger matching methods as they become available.
