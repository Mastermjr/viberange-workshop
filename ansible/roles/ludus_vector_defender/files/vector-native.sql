-- VibeRange source-native ClickHouse evidence model.
--
-- ir.raw_events is the immutable authoritative landing table. Materialized
-- projections promote stable native fields into physical source tables while
-- retaining raw_data in every row. Unknown valid events remain queryable in
-- raw_events; malformed expected-JSON records are also copied to parse_errors.

CREATE DATABASE IF NOT EXISTS ir;

CREATE TABLE IF NOT EXISTS ir.schema_migrations (
    migration_id LowCardinality(String),
    applied_at DateTime64(3, 'UTC') DEFAULT now64(3),
    description String
)
ENGINE = MergeTree
ORDER BY (migration_id, applied_at);

CREATE TABLE IF NOT EXISTS ir.raw_events (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC') DEFAULT now64(9),
    source_type LowCardinality(String),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    message String,
    raw_data String,
    vector_metadata String DEFAULT '{}',
    INDEX idx_message message TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, source_type, source_host, event_time, event_id)
TTL toDateTime(event_time) + INTERVAL 30 DAY;

CREATE TABLE IF NOT EXISTS ir.parse_errors (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC') DEFAULT now64(9),
    source_type LowCardinality(String),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    error String,
    raw_data String
)
ENGINE = MergeTree
ORDER BY (range_id, source_type, ingested_time, event_id);

CREATE TABLE IF NOT EXISTS ir.linux_auditd (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    audit_type LowCardinality(String),
    audit_serial String,
    syscall LowCardinality(String),
    success LowCardinality(String),
    pid UInt32,
    ppid UInt32,
    uid Int32,
    auid Int32,
    executable String,
    command_name LowCardinality(String),
    command_line String,
    cwd String,
    audit_key LowCardinality(String),
    raw_data String,
    INDEX idx_audit_executable executable TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4,
    INDEX idx_audit_command command_line TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, source_host, event_time, event_id);

CREATE TABLE IF NOT EXISTS ir.kubernetes_audit (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    audit_id String,
    stage LowCardinality(String),
    verb LowCardinality(String),
    username LowCardinality(String),
    user_groups Array(String),
    source_ips Array(String),
    user_agent String,
    request_uri String,
    api_group LowCardinality(String),
    api_version LowCardinality(String),
    resource LowCardinality(String),
    subresource LowCardinality(String),
    namespace LowCardinality(String),
    object_name String,
    response_code UInt16,
    raw_data String,
    INDEX idx_k8s_user username TYPE bloom_filter GRANULARITY 4,
    INDEX idx_k8s_object object_name TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, namespace, resource, event_time, event_id);

CREATE TABLE IF NOT EXISTS ir.tetragon_events (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    event_type LowCardinality(String),
    node_name LowCardinality(String),
    namespace LowCardinality(String),
    pod_name String,
    container_name String,
    container_id String,
    exec_id String,
    parent_exec_id String,
    pid UInt32,
    parent_pid UInt32,
    uid UInt32,
    binary String,
    arguments String,
    cwd String,
    policy_name LowCardinality(String),
    function_name String,
    action LowCardinality(String),
    raw_data String,
    INDEX idx_tetragon_exec exec_id TYPE bloom_filter GRANULARITY 4,
    INDEX idx_tetragon_binary binary TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, namespace, pod_name, event_time, event_id);

CREATE TABLE IF NOT EXISTS ir.container_logs (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    file_path String,
    stream LowCardinality(String),
    message String,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, source_host, file_path, event_time, event_id);

CREATE TABLE IF NOT EXISTS ir.caldera_operations (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    operation_id String,
    adversary_id String,
    operation_name String,
    state LowCardinality(String),
    started_at Nullable(DateTime64(9, 'UTC')),
    finished_at Nullable(DateTime64(9, 'UTC')),
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, operation_id, event_time, event_id);

CREATE TABLE IF NOT EXISTS ir.caldera_links (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    operation_id String,
    link_id String,
    ability_id String,
    agent_paw String,
    command String,
    status LowCardinality(String),
    delegated_at Nullable(DateTime64(9, 'UTC')),
    finished_at Nullable(DateTime64(9, 'UTC')),
    result String,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, operation_id, event_time, link_id, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_events (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    zeek_path LowCardinality(String),
    zeek_uid String,
    src_ip String,
    src_port UInt16,
    dst_ip String,
    dst_port UInt16,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, zeek_path, event_time, zeek_uid, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_conn (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    zeek_uid String,
    src_ip String,
    src_port UInt16,
    dst_ip String,
    dst_port UInt16,
    protocol LowCardinality(String),
    service LowCardinality(String),
    duration Float64,
    orig_bytes UInt64,
    resp_bytes UInt64,
    conn_state LowCardinality(String),
    history String,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, src_ip, dst_ip, event_time, zeek_uid, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_dns (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    zeek_uid String,
    query String,
    qtype_name LowCardinality(String),
    rcode_name LowCardinality(String),
    answers Array(String),
    rejected Bool,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, query, event_time, zeek_uid, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_http (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    zeek_uid String,
    method LowCardinality(String),
    host String,
    uri String,
    status_code UInt16,
    user_agent String,
    resp_mime_types Array(String),
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, host, event_time, zeek_uid, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_tls (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    zeek_uid String,
    version LowCardinality(String),
    cipher String,
    server_name String,
    established Bool,
    resumed Bool,
    subject String,
    issuer String,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, server_name, event_time, zeek_uid, event_id);

CREATE TABLE IF NOT EXISTS ir.zeek_notice (
    event_id UUID,
    event_time DateTime64(9, 'UTC'),
    ingested_time DateTime64(9, 'UTC'),
    source_host LowCardinality(String),
    range_id LowCardinality(String),
    note LowCardinality(String),
    message String,
    sub String,
    src_ip String,
    dst_ip String,
    dst_port UInt16,
    raw_data String
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (range_id, note, event_time, event_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_linux_auditd TO ir.linux_auditd AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'type') AS audit_type,
       JSONExtractString(raw_data, 'audit_serial') AS audit_serial,
       JSONExtractString(raw_data, 'syscall') AS syscall,
       JSONExtractString(raw_data, 'success') AS success,
       toUInt32OrZero(JSONExtractString(raw_data, 'pid')) AS pid,
       toUInt32OrZero(JSONExtractString(raw_data, 'ppid')) AS ppid,
       toInt32OrZero(JSONExtractString(raw_data, 'uid')) AS uid,
       toInt32OrZero(JSONExtractString(raw_data, 'auid')) AS auid,
       JSONExtractString(raw_data, 'exe') AS executable,
       JSONExtractString(raw_data, 'comm') AS command_name,
       JSONExtractString(raw_data, 'proctitle') AS command_line,
       JSONExtractString(raw_data, 'cwd') AS cwd,
       JSONExtractString(raw_data, 'key') AS audit_key,
       raw_data
FROM ir.raw_events
WHERE source_type = 'linux_auditd' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_kubernetes_audit TO ir.kubernetes_audit AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'auditID') AS audit_id,
       JSONExtractString(raw_data, 'stage') AS stage,
       JSONExtractString(raw_data, 'verb') AS verb,
       JSONExtractString(raw_data, 'user', 'username') AS username,
       JSONExtract(raw_data, 'user', 'groups', 'Array(String)') AS user_groups,
       JSONExtract(raw_data, 'sourceIPs', 'Array(String)') AS source_ips,
       JSONExtractString(raw_data, 'userAgent') AS user_agent,
       JSONExtractString(raw_data, 'requestURI') AS request_uri,
       JSONExtractString(raw_data, 'objectRef', 'apiGroup') AS api_group,
       JSONExtractString(raw_data, 'objectRef', 'apiVersion') AS api_version,
       JSONExtractString(raw_data, 'objectRef', 'resource') AS resource,
       JSONExtractString(raw_data, 'objectRef', 'subresource') AS subresource,
       JSONExtractString(raw_data, 'objectRef', 'namespace') AS namespace,
       JSONExtractString(raw_data, 'objectRef', 'name') AS object_name,
       toUInt16(JSONExtractUInt(raw_data, 'responseStatus', 'code')) AS response_code,
       raw_data
FROM ir.raw_events
WHERE source_type = 'kubernetes_audit' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_tetragon TO ir.tetragon_events AS
WITH
    multiIf(JSONHas(raw_data, 'process_exec'), 'process_exec',
            JSONHas(raw_data, 'process_exit'), 'process_exit',
            JSONHas(raw_data, 'process_kprobe'), 'process_kprobe',
            JSONHas(raw_data, 'process_tracepoint'), 'process_tracepoint',
            JSONHas(raw_data, 'process_uprobe'), 'process_uprobe',
            JSONHas(raw_data, 'process_loader'), 'process_loader', 'unknown') AS event_type_value,
    multiIf(event_type_value = 'process_exec', JSONExtractRaw(raw_data, 'process_exec'),
            event_type_value = 'process_exit', JSONExtractRaw(raw_data, 'process_exit'),
            event_type_value = 'process_kprobe', JSONExtractRaw(raw_data, 'process_kprobe'),
            event_type_value = 'process_tracepoint', JSONExtractRaw(raw_data, 'process_tracepoint'),
            event_type_value = 'process_uprobe', JSONExtractRaw(raw_data, 'process_uprobe'),
            event_type_value = 'process_loader', JSONExtractRaw(raw_data, 'process_loader'), '{}') AS event_json,
    JSONExtractRaw(event_json, 'process') AS process_json,
    JSONExtractRaw(event_json, 'parent') AS parent_json
SELECT event_id, event_time, ingested_time, source_host, range_id,
       event_type_value AS event_type,
       JSONExtractString(raw_data, 'node_name') AS node_name,
       JSONExtractString(process_json, 'pod', 'namespace') AS namespace,
       JSONExtractString(process_json, 'pod', 'name') AS pod_name,
       JSONExtractString(process_json, 'pod', 'container', 'name') AS container_name,
       JSONExtractString(process_json, 'pod', 'container', 'id') AS container_id,
       JSONExtractString(process_json, 'exec_id') AS exec_id,
       JSONExtractString(process_json, 'parent_exec_id') AS parent_exec_id,
       toUInt32(JSONExtractUInt(process_json, 'pid')) AS pid,
       toUInt32(JSONExtractUInt(parent_json, 'pid')) AS parent_pid,
       toUInt32(JSONExtractUInt(process_json, 'uid')) AS uid,
       JSONExtractString(process_json, 'binary') AS binary,
       JSONExtractString(process_json, 'arguments') AS arguments,
       JSONExtractString(process_json, 'cwd') AS cwd,
       JSONExtractString(event_json, 'policy_name') AS policy_name,
       coalesce(nullIf(JSONExtractString(event_json, 'function_name'), ''),
                nullIf(JSONExtractString(event_json, 'subsys'), ''), '') AS function_name,
       JSONExtractString(event_json, 'action') AS action,
       raw_data
FROM ir.raw_events
WHERE source_type = 'tetragon' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_container_logs TO ir.container_logs AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(vector_metadata, 'file') AS file_path,
       if(position(message, ' stdout ') > 0, 'stdout', if(position(message, ' stderr ') > 0, 'stderr', '')) AS stream,
       message,
       raw_data
FROM ir.raw_events
WHERE source_type = 'container_log';

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_caldera_operations TO ir.caldera_operations AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'id') AS operation_id,
       coalesce(nullIf(JSONExtractString(raw_data, 'adversary', 'adversary_id'), ''), JSONExtractString(raw_data, 'adversary_id')) AS adversary_id,
       JSONExtractString(raw_data, 'name') AS operation_name,
       JSONExtractString(raw_data, 'state') AS state,
       parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'start')) AS started_at,
       parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'finish')) AS finished_at,
       raw_data
FROM ir.raw_events
WHERE source_type = 'caldera_operation' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_caldera_links TO ir.caldera_links AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'operation_id') AS operation_id,
       JSONExtractString(raw_data, 'id') AS link_id,
       JSONExtractString(raw_data, 'ability', 'ability_id') AS ability_id,
       JSONExtractString(raw_data, 'paw') AS agent_paw,
       JSONExtractString(raw_data, 'command') AS command,
       JSONExtractString(raw_data, 'status') AS status,
       parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'decide')) AS delegated_at,
       parseDateTime64BestEffortOrNull(JSONExtractString(raw_data, 'finish')) AS finished_at,
       JSONExtractString(raw_data, 'output') AS result,
       raw_data
FROM ir.raw_events
WHERE source_type = 'caldera_link' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_events TO ir.zeek_events AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, '_path') AS zeek_path,
       JSONExtractString(raw_data, 'uid') AS zeek_uid,
       JSONExtractString(raw_data, 'id.orig_h') AS src_ip,
       toUInt16(JSONExtractUInt(raw_data, 'id.orig_p')) AS src_port,
       JSONExtractString(raw_data, 'id.resp_h') AS dst_ip,
       toUInt16(JSONExtractUInt(raw_data, 'id.resp_p')) AS dst_port,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_conn TO ir.zeek_conn AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'uid') AS zeek_uid,
       JSONExtractString(raw_data, 'id.orig_h') AS src_ip,
       toUInt16(JSONExtractUInt(raw_data, 'id.orig_p')) AS src_port,
       JSONExtractString(raw_data, 'id.resp_h') AS dst_ip,
       toUInt16(JSONExtractUInt(raw_data, 'id.resp_p')) AS dst_port,
       JSONExtractString(raw_data, 'proto') AS protocol,
       JSONExtractString(raw_data, 'service') AS service,
       JSONExtractFloat(raw_data, 'duration') AS duration,
       JSONExtractUInt(raw_data, 'orig_bytes') AS orig_bytes,
       JSONExtractUInt(raw_data, 'resp_bytes') AS resp_bytes,
       JSONExtractString(raw_data, 'conn_state') AS conn_state,
       JSONExtractString(raw_data, 'history') AS history,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND JSONExtractString(raw_data, '_path') = 'conn' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_dns TO ir.zeek_dns AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'uid') AS zeek_uid,
       JSONExtractString(raw_data, 'query') AS query,
       JSONExtractString(raw_data, 'qtype_name') AS qtype_name,
       JSONExtractString(raw_data, 'rcode_name') AS rcode_name,
       JSONExtract(raw_data, 'answers', 'Array(String)') AS answers,
       JSONExtractBool(raw_data, 'rejected') AS rejected,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND JSONExtractString(raw_data, '_path') = 'dns' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_http TO ir.zeek_http AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'uid') AS zeek_uid,
       JSONExtractString(raw_data, 'method') AS method,
       JSONExtractString(raw_data, 'host') AS host,
       JSONExtractString(raw_data, 'uri') AS uri,
       toUInt16(JSONExtractUInt(raw_data, 'status_code')) AS status_code,
       JSONExtractString(raw_data, 'user_agent') AS user_agent,
       JSONExtract(raw_data, 'resp_mime_types', 'Array(String)') AS resp_mime_types,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND JSONExtractString(raw_data, '_path') = 'http' AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_tls TO ir.zeek_tls AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'uid') AS zeek_uid,
       JSONExtractString(raw_data, 'version') AS version,
       JSONExtractString(raw_data, 'cipher') AS cipher,
       JSONExtractString(raw_data, 'server_name') AS server_name,
       JSONExtractBool(raw_data, 'established') AS established,
       JSONExtractBool(raw_data, 'resumed') AS resumed,
       JSONExtractString(raw_data, 'subject') AS subject,
       JSONExtractString(raw_data, 'issuer') AS issuer,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND JSONExtractString(raw_data, '_path') IN ('ssl', 'tls') AND isValidJSON(raw_data);

CREATE MATERIALIZED VIEW IF NOT EXISTS ir.mv_raw_to_zeek_notice TO ir.zeek_notice AS
SELECT event_id, event_time, ingested_time, source_host, range_id,
       JSONExtractString(raw_data, 'note') AS note,
       JSONExtractString(raw_data, 'msg') AS message,
       JSONExtractString(raw_data, 'sub') AS sub,
       JSONExtractString(raw_data, 'src') AS src_ip,
       JSONExtractString(raw_data, 'dst') AS dst_ip,
       toUInt16(JSONExtractUInt(raw_data, 'p')) AS dst_port,
       raw_data
FROM ir.raw_events
WHERE source_type = 'zeek' AND JSONExtractString(raw_data, '_path') = 'notice' AND isValidJSON(raw_data);
