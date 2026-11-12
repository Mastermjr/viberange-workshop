-- Append-only experiment run state and query-time evidence membership.
-- Agents do not restart or change environment variables between runs.

CREATE TABLE IF NOT EXISTS ir.experiment_run_events (
    run_event_id UUID,
    run_id LowCardinality(String),
    recorded_at DateTime64(9, 'UTC'),
    range_id LowCardinality(String),
    scenario_id LowCardinality(String),
    scenario_version LowCardinality(String),
    blueprint_version LowCardinality(String),
    source_ref LowCardinality(String),
    operator String,
    status LowCardinality(String),
    started_at Nullable(DateTime64(9, 'UTC')),
    ended_at Nullable(DateTime64(9, 'UTC')),
    caldera_operation_id String,
    adversary_id String,
    manifest_path String,
    notes String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(recorded_at)
ORDER BY (range_id, run_id, recorded_at, run_event_id);

CREATE OR REPLACE VIEW ir.experiment_runs AS
SELECT
    *,
    if(started_at IS NULL, 0,
       dateDiff('millisecond', assumeNotNull(started_at), coalesce(ended_at, now64(9)))) AS duration_ms
FROM
(
    SELECT
        run_id,
        argMax(range_id, tuple(recorded_at, run_event_id)) AS range_id,
        argMax(scenario_id, tuple(recorded_at, run_event_id)) AS scenario_id,
        argMax(scenario_version, tuple(recorded_at, run_event_id)) AS scenario_version,
        argMax(blueprint_version, tuple(recorded_at, run_event_id)) AS blueprint_version,
        argMax(source_ref, tuple(recorded_at, run_event_id)) AS source_ref,
        argMax(operator, tuple(recorded_at, run_event_id)) AS operator,
        argMax(status, tuple(recorded_at, run_event_id)) AS status,
        tupleElement(argMax(tuple(started_at), tuple(recorded_at, run_event_id)), 1) AS started_at,
        tupleElement(argMax(tuple(ended_at), tuple(recorded_at, run_event_id)), 1) AS ended_at,
        argMax(caldera_operation_id, tuple(recorded_at, run_event_id)) AS caldera_operation_id,
        argMax(adversary_id, tuple(recorded_at, run_event_id)) AS adversary_id,
        argMax(manifest_path, tuple(recorded_at, run_event_id)) AS manifest_path,
        argMax(notes, tuple(recorded_at, run_event_id)) AS notes,
        min(recorded_at) AS created_at
    FROM ir.experiment_run_events
    GROUP BY run_id
);

CREATE OR REPLACE VIEW ir.raw_events_by_run AS
SELECT
    runs.run_id AS run_id,
    runs.scenario_id AS scenario_id,
    runs.scenario_version AS scenario_version,
    if(JSONExtractString(raw.raw_data, 'run_id') != '',
       'explicit_run_id', 'range_time_window') AS membership_method,
    raw.event_id AS event_id,
    raw.event_time AS event_time,
    raw.ingested_time AS ingested_time,
    raw.source_type AS source_type,
    raw.source_host AS source_host,
    raw.range_id AS range_id,
    raw.message AS message,
    raw.raw_data AS raw_data,
    raw.vector_metadata AS vector_metadata
FROM ir.raw_events AS raw
INNER JOIN ir.experiment_runs AS runs ON raw.range_id = runs.range_id
WHERE runs.status != 'invalidated'
  AND runs.started_at IS NOT NULL
  AND
  (
      (JSONExtractString(raw.raw_data, 'run_id') != ''
       AND JSONExtractString(raw.raw_data, 'run_id') = runs.run_id)
      OR
      (JSONExtractString(raw.raw_data, 'run_id') = ''
       AND raw.event_time >= assumeNotNull(runs.started_at)
       AND raw.event_time <= coalesce(runs.ended_at, now64(9)))
  );

CREATE OR REPLACE VIEW ir.run_evidence_counts AS
SELECT
    run_id,
    scenario_id,
    scenario_version,
    source_type,
    source_host,
    count() AS events,
    min(event_time) AS first_event,
    max(event_time) AS last_event,
    dateDiff('millisecond', first_event, last_event) AS observed_span_ms
FROM ir.raw_events_by_run
GROUP BY run_id, scenario_id, scenario_version, source_type, source_host;
