#!/usr/bin/env bash
set -euo pipefail

CLICKHOUSE_URL="${CLICKHOUSE_URL:-http://127.0.0.1:8123}"

echo "== ClickHouse ping =="
curl -fsS "$CLICKHOUSE_URL/ping"
echo

echo "== Source-native tables =="
curl -fsS --data-binary "
SELECT name, engine, total_rows
FROM system.tables
WHERE database = 'ir'
  AND name IN (
    'raw_events','parse_errors','linux_auditd','kubernetes_audit',
    'tetragon_events','container_logs','caldera_operations','caldera_links',
    'zeek_events','zeek_conn','zeek_dns','zeek_http','zeek_tls','zeek_notice',
    'detections','schema_migrations'
  )
ORDER BY name
FORMAT PrettyCompactMonoBlock
" "$CLICKHOUSE_URL"
echo

for q in \
  "SELECT source_type, count() AS events FROM ir.raw_events GROUP BY source_type ORDER BY source_type" \
  "SELECT 'linux_auditd' AS table, count() AS rows FROM ir.linux_auditd UNION ALL SELECT 'kubernetes_audit', count() FROM ir.kubernetes_audit UNION ALL SELECT 'tetragon_events', count() FROM ir.tetragon_events UNION ALL SELECT 'container_logs', count() FROM ir.container_logs UNION ALL SELECT 'caldera_operations', count() FROM ir.caldera_operations UNION ALL SELECT 'zeek_events', count() FROM ir.zeek_events" \
  "SELECT count() AS parse_errors FROM ir.parse_errors" \
  "SELECT count() AS detections FROM ir.detections"; do
  echo "-- $q"
  curl -fsS --data-binary "$q" "$CLICKHOUSE_URL"
  echo
done
