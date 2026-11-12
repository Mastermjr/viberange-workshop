#!/usr/bin/env bash
set -euo pipefail

CLICKHOUSE_URL="${CLICKHOUSE_URL:-http://127.0.0.1:8123}"
SINCE_MINUTES="${SINCE_MINUTES:-30}"
RANGE_ID="${RANGE_ID:-}"

range_filter=""
if [[ -n "$RANGE_ID" ]]; then
  range_filter="AND range_id = '${RANGE_ID//\'/\'\'}'"
fi

echo "== Recent authoritative telemetry by source and host =="
curl -fsS --data-binary "
SELECT
  range_id,
  source_type,
  source_host,
  count() AS events,
  min(event_time) AS first_seen,
  max(event_time) AS last_seen
FROM ir.raw_events
WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE
  ${range_filter}
GROUP BY range_id, source_type, source_host
ORDER BY range_id, source_type, source_host
FORMAT PrettyCompactMonoBlock
" "$CLICKHOUSE_URL"

echo

echo "== Recent source projection counts =="
curl -fsS --data-binary "
SELECT 'linux_auditd' AS source_table, count() AS events FROM ir.linux_auditd WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
UNION ALL SELECT 'kubernetes_audit', count() FROM ir.kubernetes_audit WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
UNION ALL SELECT 'tetragon_events', count() FROM ir.tetragon_events WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
UNION ALL SELECT 'container_logs', count() FROM ir.container_logs WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
UNION ALL SELECT 'caldera_operations', count() FROM ir.caldera_operations WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
UNION ALL SELECT 'zeek_events', count() FROM ir.zeek_events WHERE event_time > now() - INTERVAL ${SINCE_MINUTES} MINUTE ${range_filter}
FORMAT PrettyCompactMonoBlock
" "$CLICKHOUSE_URL"

echo

echo "== Recent detections =="
curl -fsS --data-binary "
SELECT time, rule_id, rule_name, severity, matched_source, matched_host, experiment_run
FROM ir.detections
ORDER BY time DESC
LIMIT 20
FORMAT PrettyCompactMonoBlock
" "$CLICKHOUSE_URL"
