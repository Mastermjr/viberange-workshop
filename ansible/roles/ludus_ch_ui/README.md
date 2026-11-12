# `ludus_ch_ui`

Installs a pinned CH-UI server on the VibeRange `clickhouse-ir` analysis VM and
prepares a participant-facing catalog of evidence searches and dashboards for
the existing `ir` ClickHouse database.

This role is intentionally adjacent to the existing workshop roles:

```text
ansible/roles/
├── ludus_clickhouse_ir/
├── ludus_vector_defender/       # central Vector aggregator
├── ludus_vector_attacker/
├── ludus_vector_victim/
├── ludus_vector_router/
└── ludus_ch_ui/                  # this role
```

## Contract

The role must:

1. install CH-UI from a pinned upstream release with a SHA-256 check;
2. run it as a dedicated unprivileged systemd service;
3. keep its SQLite state under `/var/lib/ch-ui`;
4. connect only to the local ClickHouse HTTP listener;
5. expose the participant UI on TCP/3488 through an explicit Ludus policy;
6. create no second evidence database and perform no telemetry ingestion;
7. seed version-controlled, shared, verified searches for the `ir` schema;
8. seed a VibeRange live-evidence dashboard;
9. preserve state across restart and remain idempotent on redeployment;
10. keep passwords, session keys, and other generated secrets out of Git,
    issue trackers, deployment logs, and saved-query definitions.

CH-UI is a presentation and query layer. `ir.raw_events` and its source views
remain authoritative forensic evidence. CH-UI pipelines, ingest receivers, AI
providers, and write-oriented ClickHouse administration are not workshop
requirements.

## Upstream baseline

The integration is pinned to:

| Item | Value |
|---|---|
| Project | <https://github.com/caioricciuti/ch-ui> |
| Reviewed source revision | `a30774c642450153456760c593796dca2a8c32dd` |
| Release | `v2.32.0` |
| Linux amd64 SHA-256 | `eb1fa7973e7c5a010fbb12c36dda65ee3b7442e277662499e2e95a29701ffe89` |
| License | Apache-2.0 community features; BSL-1.1 Pro features |

Relevant upstream material reviewed before implementation:

- installation, architecture, configuration, server/desktop mode, connection,
  backup, saved-query, dashboard, and production-checklist sections in the
  upstream README;
- `internal/server/handlers/saved_queries.go` for the authenticated,
  writer-gated saved-query API;
- `internal/server/handlers/dashboards.go` for dashboard creation/import;
- `internal/server/handlers/auth.go` for ClickHouse-backed login and role
  detection;
- `internal/config/config.go` for server configuration precedence and defaults;
- the upstream `clickhouse-analytics` skill, vendored with attribution under
  `docs/upstream/ch-ui/`.

## Deployment

```text
participant browser
       │ TCP/3488
       ▼
CH-UI server (systemd, ch-ui user, SQLite state)
       │ http://127.0.0.1:8123
       ▼
ClickHouse ir.raw_events and source-specific views
```

Default paths:

```text
/usr/local/bin/ch-ui
/etc/ch-ui/server.yaml
/var/lib/ch-ui/ch-ui.db
/var/lib/ch-ui/.app-secret-key
/etc/systemd/system/ch-ui.service
```

The role uses server mode, not Docker. The workshop analysis template preinstalls the pinned binary and versioned seed definitions, while this role still creates the range-specific connection, participant account, SQLite state, searches, and dashboards at first boot.

This keeps mutable application state reproducible through the role, preserves the standard Debian fallback, and allows CH-UI content to be upgraded or reset independently of the golden image.

## Search catalog

Version-controlled definitions live in the role's JSON templates. The catalog
and dashboards cover:

- source freshness and row rates;
- Vector source/host health;
- Kali auditd process activity;
- Kubernetes API users, verbs, resources, and authorization results;
- Tetragon process lineage and bounded socket-policy tuples;
- the participant-shippable Kubernetes/PostgreSQL telemetry proof workspace;
- an all-workload Kubernetes dashboard without namespace or validation-workload filters;
- victim Vector forwarding freshness and source-to-ingestion latency;
- Zeek connections and protocol views;
- Caldera operation ground truth;
- parse errors and unknown-source review;
- marked delivery and outage-recovery evidence;
- bounded time-window reconstruction queries;
- expected-machine evidence coverage, freshness, and per-machine event volume.

Shared queries are visible to participant viewer accounts. Seeding is performed
idempotently by name and versioned content; manually created participant
queries are not deleted or overwritten.

## Security boundary

- CH-UI binds to the analysis VM, never the public internet.
- Ludus exposes TCP/3488 only through the documented participant/operator path.
- Participant ClickHouse accounts are read-only.
- The application secret is generated on the VM and stored root-readable only.
- Saved queries contain SQL only—no credentials or environment secrets.
- CH-UI executes queries with the logged-in ClickHouse user's grants; the UI is
  not treated as an authorization boundary by itself.

## Acceptance

The role passes when a clean `test` deployment proves:

1. `ch-ui.service` is active and `/health` succeeds;
2. login reaches the local ClickHouse connection;
3. expected shared searches, live dashboard, scoped nine-panel Kubernetes telemetry proof dashboard, and unfiltered nine-panel all-workload Kubernetes dashboard are present;
4. searches return rows from the live `test` range;
5. participant credentials cannot insert, alter, or drop evidence;
6. restart preserves searches, dashboards, and connection state;
7. a second role run reports no destructive drift;
8. Vector and ClickHouse continue operating while CH-UI is stopped.
