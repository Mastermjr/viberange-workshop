-- Deterministic, source-citing reconstruction views.
-- Every association states whether membership was explicit or time bounded.

CREATE OR REPLACE VIEW ir.timeline AS
SELECT
    run_id, scenario_id, scenario_version, event_id, event_time, ingested_time,
    dataset, source_host, membership_method, namespace, pod_name, process,
    user_name, src_ip, src_port, dst_ip, dst_port, protocol,
    caldera_operation_id, caldera_link_id, exec_id, parent_exec_id, zeek_uid,
    artifact_id, summary, raw_data
FROM
(
    SELECT
        e.run_id AS run_id,
        e.scenario_id AS scenario_id,
        e.scenario_version AS scenario_version,
        toString(e.run_event_id) AS event_id,
        toDateTime64(e.recorded_at, 9, 'UTC') AS event_time,
        toDateTime64(e.recorded_at, 9, 'UTC') AS ingested_time,
        'experiment_run' AS dataset,
        '' AS source_host,
        'explicit_run_id' AS membership_method,
        '' AS namespace,
        '' AS pod_name,
        '' AS process,
        e.operator AS user_name,
        '' AS src_ip,
        toUInt32(0) AS src_port,
        '' AS dst_ip,
        toUInt32(0) AS dst_port,
        '' AS protocol,
        e.caldera_operation_id AS caldera_operation_id,
        '' AS caldera_link_id,
        '' AS exec_id,
        '' AS parent_exec_id,
        '' AS zeek_uid,
        '' AS artifact_id,
        concat('run status: ', e.status) AS summary,
        e.notes AS raw_data
    FROM ir.experiment_run_events AS e

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(a.event_id),
        toDateTime64(a.event_time, 9, 'UTC'), toDateTime64(a.ingested_time, 9, 'UTC'),
        'linux_auditd', a.source_host, m.membership_method, '', '',
        if(a.command_name != '', a.command_name, a.executable), toString(a.uid),
        '', toUInt32(0), '', toUInt32(0), '', '', '', '', '', '', '',
        concat(a.audit_type, ' ', a.executable, ' ', a.command_line), a.raw_data
    FROM ir.linux_auditd AS a
    INNER JOIN ir.raw_events_by_run AS m ON a.event_id = m.event_id
    WHERE m.source_type = 'linux_auditd'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(k.event_id),
        toDateTime64(k.event_time, 9, 'UTC'), toDateTime64(k.ingested_time, 9, 'UTC'),
        'kubernetes_audit', k.source_host, m.membership_method, k.namespace,
        if(k.resource = 'pods', k.object_name, ''), '', k.username,
        arrayStringConcat(k.source_ips, ','), toUInt32(0), '', toUInt32(0), '',
        '', '', '', '', '', '',
        concat(k.verb, ' ', k.resource, '/', k.object_name, ' -> ', toString(k.response_code)),
        k.raw_data
    FROM ir.kubernetes_audit AS k
    INNER JOIN ir.raw_events_by_run AS m ON k.event_id = m.event_id
    WHERE m.source_type = 'kubernetes_audit'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(t.event_id),
        toDateTime64(t.event_time, 9, 'UTC'), toDateTime64(t.ingested_time, 9, 'UTC'),
        'tetragon', t.source_host, m.membership_method, t.namespace, t.pod_name,
        t.binary, toString(t.uid), '', toUInt32(0), '', toUInt32(0), '',
        '', '', t.exec_id, t.parent_exec_id, '', '',
        concat(t.event_type, ' ', t.binary, ' ', t.arguments), t.raw_data
    FROM ir.tetragon_events AS t
    INNER JOIN ir.raw_events_by_run AS m ON t.event_id = m.event_id
    WHERE m.source_type = 'tetragon'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(z.event_id),
        toDateTime64(z.event_time, 9, 'UTC'), toDateTime64(z.ingested_time, 9, 'UTC'),
        'zeek_conn', z.source_host, m.membership_method, '', '', '', '',
        z.src_ip, toUInt32(z.src_port), z.dst_ip, toUInt32(z.dst_port), z.protocol,
        '', '', '', '', z.zeek_uid,
        JSONExtractString(z.raw_data, 'artifact_id'),
        concat(z.protocol, '/', z.service, ' ', z.src_ip, ':', toString(z.src_port),
               ' -> ', z.dst_ip, ':', toString(z.dst_port), ' ', z.conn_state),
        z.raw_data
    FROM ir.zeek_conn AS z
    INNER JOIN ir.raw_events_by_run AS m ON z.event_id = m.event_id
    WHERE m.source_type = 'zeek'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(c.event_id),
        toDateTime64(c.event_time, 9, 'UTC'), toDateTime64(c.ingested_time, 9, 'UTC'),
        'container_log', c.source_host, m.membership_method, '', '', '', '',
        '', toUInt32(0), '', toUInt32(0), '', '', '', '', '', '', '',
        left(c.message, 500), c.raw_data
    FROM ir.container_logs AS c
    INNER JOIN ir.raw_events_by_run AS m ON c.event_id = m.event_id
    WHERE m.source_type = 'container_log'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(p.event_id),
        toDateTime64(p.event_time, 9, 'UTC'), toDateTime64(p.ingested_time, 9, 'UTC'),
        'pcap_artifact', p.source_host, m.membership_method, '', '', '', '',
        '', toUInt32(0), '', toUInt32(0), '', '', '', '', '', '', p.artifact_id,
        concat('sealed PCAP ', p.pcap_sha256, ' packets=', toString(p.packet_count)),
        p.raw_data
    FROM ir.pcap_artifacts AS p
    INNER JOIN ir.raw_events_by_run AS m ON p.event_id = m.event_id
    WHERE m.source_type = 'pcap_artifact'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(o.event_id),
        toDateTime64(coalesce(o.started_at, o.event_time), 9, 'UTC'),
        toDateTime64(o.ingested_time, 9, 'UTC'),
        'caldera_operation', o.source_host, m.membership_method, '', '', '', '',
        '', toUInt32(0), '', toUInt32(0), '', o.operation_id, '', '', '', '', '',
        concat(o.operation_name, ' state=', o.state), o.raw_data
    FROM ir.caldera_operations AS o
    INNER JOIN ir.raw_events_by_run AS m ON o.event_id = m.event_id
    WHERE m.source_type = 'caldera_operation'

    UNION ALL

    SELECT
        m.run_id, m.scenario_id, m.scenario_version, toString(l.event_id),
        toDateTime64(coalesce(l.delegated_at, l.event_time), 9, 'UTC'),
        toDateTime64(l.ingested_time, 9, 'UTC'),
        'caldera_link', l.source_host, m.membership_method, '', '', l.command, '',
        '', toUInt32(0), '', toUInt32(0), '', l.operation_id, l.link_id, '', '', '', '',
        concat(l.ability_id, ' status=', l.status, ' agent=', l.agent_paw), l.raw_data
    FROM ir.caldera_links AS l
    INNER JOIN ir.raw_events_by_run AS m ON l.event_id = m.event_id
    WHERE m.source_type = 'caldera_link'

    UNION ALL

    SELECT
        d.experiment_run, r.scenario_id, r.scenario_version,
        concat('detection:', d.rule_id, ':', toString(d.time)),
        toDateTime64(d.time, 9, 'UTC'), toDateTime64(d.time, 9, 'UTC'),
        'detection', d.matched_host, 'explicit_run_id', '', '', '', '',
        '', toUInt32(0), '', toUInt32(0), '', r.caldera_operation_id, '', '', '', '', '',
        concat(d.rule_name, ' severity=', d.severity, ' matches=', arrayStringConcat(d.matched_event_ids, ',')),
        d.raw
    FROM ir.detections AS d
    INNER JOIN ir.experiment_runs AS r ON d.experiment_run = r.run_id
);

CREATE OR REPLACE VIEW ir.process_lineage AS
SELECT
    run_id, event_id, event_time, source_host, namespace, pod_name, process,
    exec_id, parent_exec_id, summary, raw_data
FROM ir.timeline
WHERE dataset = 'tetragon' AND exec_id != '';

CREATE OR REPLACE VIEW ir.network_connections AS
SELECT
    run_id, event_id, event_time, source_host, src_ip, src_port, dst_ip, dst_port,
    protocol, zeek_uid, artifact_id, summary, raw_data
FROM ir.timeline
WHERE dataset = 'zeek_conn';

CREATE OR REPLACE VIEW ir.kubernetes_actions AS
SELECT
    run_id, event_id, event_time, source_host, namespace, pod_name, user_name,
    summary, raw_data
FROM ir.timeline
WHERE dataset = 'kubernetes_audit';

CREATE OR REPLACE VIEW ir.caldera_execution AS
SELECT
    run_id, event_id, event_time, dataset, source_host, process,
    caldera_operation_id, caldera_link_id, summary, raw_data
FROM ir.timeline
WHERE dataset IN ('caldera_operation', 'caldera_link');

CREATE OR REPLACE VIEW ir.kubernetes_tetragon_correlation AS
SELECT
    k.run_id AS run_id,
    k.event_id AS kubernetes_event_id,
    t.event_id AS tetragon_event_id,
    k.event_time AS kubernetes_time,
    t.event_time AS tetragon_time,
    abs(dateDiff('millisecond', k.event_time, t.event_time)) AS delta_ms,
    k.namespace AS namespace,
    k.pod_name AS pod_name,
    t.process AS process,
    t.exec_id AS exec_id,
    t.parent_exec_id AS parent_exec_id,
    'same_run_namespace_pod_within_5s' AS correlation_method
FROM ir.timeline AS k
INNER JOIN ir.timeline AS t
    ON k.run_id = t.run_id
   AND k.namespace = t.namespace
   AND k.pod_name = t.pod_name
WHERE k.dataset = 'kubernetes_audit'
  AND t.dataset = 'tetragon'
  AND k.pod_name != ''
  AND abs(dateDiff('millisecond', k.event_time, t.event_time)) <= 5000;

CREATE OR REPLACE VIEW ir.experiment_coverage AS
SELECT
    runs.run_id AS run_id,
    runs.scenario_id AS scenario_id,
    expected.source_type AS source_type,
    ifNull(actual.events, 0) AS events,
    if(events > 0, 'present', 'missing') AS coverage
FROM
(
    SELECT run_id, scenario_id
    FROM ir.experiment_runs
    WHERE status = 'completed'
) AS runs
CROSS JOIN
(
    SELECT arrayJoin([
        'linux_auditd',
        'kubernetes_audit',
        'tetragon',
        'zeek',
        'pcap_artifact'
    ]) AS source_type
) AS expected
LEFT JOIN
(
    SELECT run_id, source_type, sum(events) AS events
    FROM ir.run_evidence_counts
    GROUP BY run_id, source_type
) AS actual
    ON runs.run_id = actual.run_id
   AND expected.source_type = actual.source_type;
