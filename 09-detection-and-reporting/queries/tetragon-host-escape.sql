-- VibeRange scenario-grounded detection: a container chroots into the mounted host filesystem.
-- Execute with clickhouse-client --param_run_id='<completed-run-id>' --queries-file ...
SELECT
    membership.run_id AS experiment_run,
    toString(event.event_id) AS event_id,
    event.event_time,
    event.range_id,
    event.source_host,
    event.namespace,
    event.pod_name,
    event.container_name,
    event.binary,
    event.arguments,
    event.exec_id,
    event.parent_exec_id
FROM ir.tetragon_events AS event
INNER JOIN ir.raw_events_by_run AS membership ON event.event_id = membership.event_id
WHERE membership.run_id = {run_id:String}
  AND membership.source_type = 'tetragon'
  AND event.event_type = 'process_exec'
  AND event.binary IN ('/usr/sbin/chroot', '/usr/bin/chroot', '/bin/chroot')
  AND startsWith(event.arguments, '/host-system ')
ORDER BY event.event_time, event.event_id;
