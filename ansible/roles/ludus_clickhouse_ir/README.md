# ludus_clickhouse_ir

Installs pinned ClickHouse, adopts it into systemd, configures workshop network
listeners, applies the small bootstrap schema, and validates database health.

```yaml
roles:
  - VibeRange.ludus_clickhouse_ir
```

On `viberange-clickhouse-ir-debian12-v1-template`, the pinned package, base layout, and empty workshop schema already exist; the role verifies the version, applies current idempotent SQL, and renders per-range listeners. Standard Debian remains supported as the install fallback.

The role owns the ClickHouse service and `ir.detections` bootstrap table. The
central Vector role owns raw evidence, physical source-native tables,
materialized projections, parse errors, and their versioned migration so that
Vector can be paused safely while derived evidence tables are rebuilt.
