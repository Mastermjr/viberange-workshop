-- VibeRange scenario-grounded detection: default service account enumerates Secrets.
-- Execute with clickhouse-client --param_run_id='<completed-run-id>' --queries-file ...
SELECT
    membership.run_id AS experiment_run,
    toString(event.event_id) AS event_id,
    event.event_time,
    event.range_id,
    event.source_host,
    event.username,
    event.verb,
    event.resource,
    event.namespace,
    event.object_name,
    event.response_code
FROM ir.kubernetes_audit AS event
INNER JOIN ir.raw_events_by_run AS membership ON event.event_id = membership.event_id
WHERE membership.run_id = {run_id:String}
  AND membership.source_type = 'kubernetes_audit'
  AND event.username = 'system:serviceaccount:default:default'
  AND event.verb = 'list'
  AND event.resource = 'secrets'
  AND event.namespace = 'default'
  AND event.response_code IN (0, 200, 403)
ORDER BY event.event_time, event.event_id;
