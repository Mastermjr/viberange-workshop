-- VibeRange ClickHouse bootstrap schema.
-- Source-native evidence tables are owned by ludus_vector_defender so their
-- creation and raw-event migration happen with central Vector stopped.

CREATE DATABASE IF NOT EXISTS ir;

-- Detection output remains available before attack-specific rules are added.
-- The run-oriented schema will advance with the reconstruction epic.
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
