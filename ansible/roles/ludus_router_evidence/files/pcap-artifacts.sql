-- Native manifest projection for sealed router PCAP artifacts.
CREATE TABLE IF NOT EXISTS ir.pcap_artifacts (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    artifact_id String,
    run_id LowCardinality(String),
    artifact_type LowCardinality(String),
    capture_interface LowCardinality(String),
    capture_filter String,
    started_at DateTime64(3, 'UTC'),
    ended_at DateTime64(3, 'UTC'),
    pcap_path String,
    pcap_sha256 FixedString(64),
    size_bytes UInt64,
    packet_count UInt64,
    zeek_version LowCardinality(String),
    zeek_log_count UInt32,
    zeek_event_count UInt64,
    sealed Bool,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, run_id, event_time, artifact_id, event_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_pcap_artifacts TO ir.pcap_artifacts AS
SELECT
    event_id,
    event_time,
    ingested_time,
    source_host,
    range_id,
    JSONExtractString(raw_data, 'artifact_id') AS artifact_id,
    JSONExtractString(raw_data, 'run_id') AS run_id,
    JSONExtractString(raw_data, 'artifact_type') AS artifact_type,
    JSONExtractString(raw_data, 'capture_interface') AS capture_interface,
    JSONExtractString(raw_data, 'capture_filter') AS capture_filter,
    ifNull(parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'started_at')), event_time) AS started_at,
    ifNull(parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'ended_at')), event_time) AS ended_at,
    JSONExtractString(raw_data, 'pcap_path') AS pcap_path,
    JSONExtractString(raw_data, 'pcap_sha256') AS pcap_sha256,
    JSONExtractUInt(raw_data, 'size_bytes') AS size_bytes,
    JSONExtractUInt(raw_data, 'packet_count') AS packet_count,
    JSONExtractString(raw_data, 'zeek_version') AS zeek_version,
    toUInt32(JSONExtractUInt(raw_data, 'zeek_log_count')) AS zeek_log_count,
    JSONExtractUInt(raw_data, 'zeek_event_count') AS zeek_event_count,
    JSONExtractBool(raw_data, 'sealed') AS sealed,
    raw_data
FROM ir.raw_events
WHERE source_type = 'pcap_artifact' AND isValidJSON(raw_data);
