-- VibeRange ClickHouse bootstrap schema.
-- Deployable source-native evidence tables live in:
-- ansible/roles/ludus_vector_defender/files/vector-native.sql

CREATE DATABASE IF NOT EXISTS ir;

CREATE TABLE IF NOT EXISTS ir.detections (
    time DateTime64(3, 'UTC'),
    rule_id LowCardinality(String),
    rule_name String,
    severity LowCardinality(String),
    matched_source LowCardinality(String),
    matched_host LowCardinality(String),
    experiment_run LowCardinality(String),
    matched_event_ids Array(String),
    raw String
)
ENGINE = MergeTree
ORDER BY (experiment_run, rule_id, time);
