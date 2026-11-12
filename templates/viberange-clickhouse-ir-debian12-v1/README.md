# VibeRange clickhouse-ir Debian 12 v1 template

Workshop-ready Ludus/Packer template for the analysis VM. Its large raw/thin
disk is assigned through Ludus' injected `proxmox_storage_pool`; select a
snapshot-capable pool with adequate free space in the target environment.

## Baked applications

- ClickHouse `25.8.33.6` LTS, selected for the host's AVX-without-AVX2 CPU;
- Vector `0.58.0`;
- CH-UI `2.32.0`;
- pinned JupyterLab/Papermill/ClickHouse Python environment and wheelhouse;
- Python and generic analysis-role prerequisites.

## Baked workshop content

`/opt/viberange/bootstrap` contains synchronized copies of the authoritative:

- ClickHouse detection and source-native schema SQL;
- physical-table and materialized-view migrations;
- PCAP artifact and run-control/reconstruction SQL;
- central Vector config/unit templates;
- CH-UI server/unit templates, saved-search catalog, both dashboards, and seed
  and viewer-validation helpers;
- the pinned Jupyter Python requirements contract.

Run `scripts/sync-clickhouse-ir-template-assets.sh sync` after changing any
source role asset. Repository validation uses its `check` mode to reject drift.
The role directories remain authoritative; template copies are build inputs.

The Packer build initializes an **empty** ClickHouse `ir` schema and records the
schema migrations already represented by the image. It intentionally leaves
Vector unconfigured and CH-UI SQLite absent because range ID, second octet,
connection identity, and range-filtered SQL must be rendered/seeded at first
boot. The Jupyter venv and wheelhouse are baked, but its no-login service
configuration, notebooks, and output are created at first boot. Those
operations are fast and remain idempotent role responsibilities.

## Never baked

- evidence rows, parse errors, detections, run records, query history;
- Vector buffers, checkpoints, logs, or final TOML;
- CH-UI SQLite, sessions, final connection, or range-specific SQL;
- participant notebooks, executed output, or scenario claims;
- external management/Git/API secrets;
- machine ID or SSH host keys.

Workshop-local credentials may be created by first-boot roles. First clone
regenerates host identity.

## Build

```bash
scripts/sync-clickhouse-ir-template-assets.sh check
ludus templates add \
  -d templates/viberange-clickhouse-ir-debian12-v1 \
  --force
ludus templates build -n viberange-clickhouse-ir-debian12-v1-template
```

Before building, require root-backed `local` to remain above the 10-GiB stop
threshold and verify `local-lvm` has sufficient thin-pool headroom. After build,
confirm the template disk is on `local-lvm`, not `local`.

## First-boot role contract

The normal blueprint roles still:

1. render ClickHouse listeners/users and verify the schema;
2. render central Vector with the assigned `range_id` and start TCP/6000;
3. create/read-only participant access and seed CH-UI with range-specific saved
   searches and dashboards;
4. configure and start Jupyter from the baked venv, generate its range-local
   token, and seed only a runtime-check notebook;
5. apply later migrations, validate checksums, and repair mismatched binaries;
6. prove service health, ingestion, idempotency, and reset cleanliness.
