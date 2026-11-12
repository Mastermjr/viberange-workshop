-- Destructive only when source_native_v1 has not completed.
-- Vector must be stopped before this script runs. raw_events and parse_errors
-- are deliberately preserved; all source projections are rebuilt from raw.

CREATE DATABASE IF NOT EXISTS ir;
CREATE TABLE IF NOT EXISTS ir.schema_migrations (
    migration_id LowCardinality(String),
    applied_at DateTime64(3, 'UTC') DEFAULT now64(3),
    description String
)
ENGINE = MergeTree
ORDER BY (migration_id, applied_at);

DROP TABLE IF EXISTS ir.mv_raw_to_linux_auditd;
DROP TABLE IF EXISTS ir.mv_raw_to_kubernetes_audit;
DROP TABLE IF EXISTS ir.mv_raw_to_tetragon;
DROP TABLE IF EXISTS ir.mv_raw_to_container_logs;
DROP TABLE IF EXISTS ir.mv_raw_to_caldera_operations;
DROP TABLE IF EXISTS ir.mv_raw_to_caldera_links;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_events;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_conn;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_dns;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_http;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_tls;
DROP TABLE IF EXISTS ir.mv_raw_to_zeek_notice;

-- Rebuild source projections as physical typed tables.
DROP TABLE IF EXISTS ir.linux_auditd;
DROP TABLE IF EXISTS ir.kubernetes_audit;
DROP TABLE IF EXISTS ir.tetragon_events;
DROP TABLE IF EXISTS ir.container_logs;
DROP TABLE IF EXISTS ir.caldera_operations;
DROP TABLE IF EXISTS ir.caldera_links;
DROP TABLE IF EXISTS ir.zeek_events;
DROP TABLE IF EXISTS ir.zeek_conn;
DROP TABLE IF EXISTS ir.zeek_dns;
DROP TABLE IF EXISTS ir.zeek_http;
DROP TABLE IF EXISTS ir.zeek_tls;
DROP TABLE IF EXISTS ir.zeek_notice;

-- Remove the incompatible common process table; active roles use source-native tables.
DROP TABLE IF EXISTS ir.ocsf_process_activity;
