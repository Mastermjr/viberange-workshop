# ludus_vector_defender

The stable `ludus_vector_defender` role identifier installs the **central Vector aggregator** on `clickhouse-ir`.

The aggregator:

- receives acknowledged Vector-protocol events on TCP/6000;
- centralizes source-aware parsing and source timestamp selection;
- preserves every event in `ir.raw_events` with its original `raw_data`;
- duplicates malformed expected-JSON records into `ir.parse_errors` without
  dropping them from the authoritative raw table;
- writes to ClickHouse locally, so edge hosts never receive ClickHouse write
  credentials;
- exposes Vector internal metrics on TCP/9598;
- owns idempotent schema migrations for physical typed source-native tables
  covering auditd, Kubernetes audit, Tetragon, Caldera,
  container logs, and Zeek;
- uses ClickHouse materialized projections so every valid new raw event is
  written to its native table while `raw_data` remains available in both.

When the analysis VM uses `viberange-clickhouse-ir-debian12-v1-template`, this
role verifies the baked Vector version, renders the range-specific TOML, and
reuses the empty preinitialized schema. It remains fully compatible with the
standard Debian template and repairs an absent or mismatched Vector package.

`ir.raw_events` remains the authoritative landing table. The physical tables
provide type enforcement, source-appropriate sorting, and simpler participant
SQL without forcing unrelated evidence into one synthetic process schema.
The versioned `tetragon_projection_v2` migration extracts the same pod,
container, process, lineage, and policy fields from exec, exit, kprobe,
tracepoint, uprobe, and loader event families instead of treating exec as the
only fully typed event.
