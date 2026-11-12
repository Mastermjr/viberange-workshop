# 02 — The `clickhouse-ir` analyst VM

`clickhouse-ir` is the main participant interaction point inside an assigned VibeRange. It hosts the experiment CLI, ClickHouse evidence store, CH-UI, detections, and the Jupyter runtime used later for the forensic notebook.

The instructor deploys and validates this VM through the canonical blueprint. Participants do not install ClickHouse or edit its server configuration.

## Assigned range address

The participant handoff identifies the assigned slot and range number. Participants receive no Ludus API credential.

Addresses use:

```text
10.<range-number>.<vlan>.<host>
```

The analyst VM is therefore:

```text
hostname: clickhouse-ir
address:  10.<range-number>.10.10
```

Participants use the JupyterLab terminal on `clickhouse-ir` through their assigned WireGuard profile; direct SSH is not part of the participant workflow.

Participants may use passwordless sudo inside their disposable analysis VM through the JupyterLab terminal. They do not receive Source, Proxmox, Ludus, host SSH, or router credentials.

## Open CH-UI

Range-relative URL:

```text
http://10.<range-number>.10.10:3488
```

The blueprint allows only the assigned WireGuard client to reach TCP/3488 on its analysis VLAN, so participants open this range-relative URL directly while connected to their profile.

### Login

Use username `default` and leave the password field blank. The assigned WireGuard profile is the network access boundary for CH-UI.

After login, confirm that the VibeRange ClickHouse connection is online, shared searches and dashboards are visible, and a query executes.

Start with a safe query:

```sql
SELECT source_type, count() AS events, max(event_time) AS latest
FROM ir.raw_events
GROUP BY source_type
ORDER BY source_type;
```

Dashboard interpretation belongs to module 03. Run-ID filtering and evidence-gap analysis belong to module 08.

## Source-native evidence store

```text
ir.raw_events                 immutable source-native landing records
ir.parse_errors               malformed expected-JSON review queue
ir.linux_auditd               physical typed audit records
ir.kubernetes_audit           physical typed Kubernetes API audit records
ir.tetragon_events            physical typed runtime records
ir.container_logs             physical CRI records
ir.caldera_operations         physical operation ground truth
ir.caldera_links              physical ability/link ground truth
ir.zeek_events                physical generic Zeek metadata
ir.zeek_conn                  physical connection metadata
ir.zeek_dns                   physical DNS metadata
ir.zeek_http                  physical HTTP metadata
ir.zeek_tls                   physical TLS metadata
ir.zeek_notice                physical notice metadata
ir.pcap_artifacts             sealed PCAP artifact manifests
ir.experiment_run_events      append-only run lifecycle
ir.detections                 SQL detection output
ir.schema_migrations          idempotent schema migration ledger
```

Every source table retains `raw_data` and a common envelope:

```text
event_id · event_time · ingested_time · source_host · range_id
```

Materialized views project valid landing records into typed source tables. Unknown events remain in raw storage. Malformed expected JSON also enters `ir.parse_errors`; it is not discarded.

## Why source-native tables

Auditd, Kubernetes audit, Tetragon, Caldera, and Zeek establish different facts. Their stable native fields remain typed independently rather than being forced into one synthetic event shape. This keeps participant SQL inspectable and preserves original evidence for verification.

## Jupyter runtime

The range includes a pinned Python virtual environment and JupyterLab service on `clickhouse-ir`. Participants open it directly through their assigned WireGuard profile; module 09 provides the reconstruction notebook and generated output workflow.

The Jupyter runtime must not download dependencies during participant use when the Source-owned analysis template is built.

## References

- [`../03-vector/README.md`](../03-vector/README.md)
- [`../08-experiment-framework/README.md`](../08-experiment-framework/README.md)
- [`../09-detection-and-reporting/README.md`](../09-detection-and-reporting/README.md)
- [`../ansible/roles/ludus_ch_ui/README.md`](../ansible/roles/ludus_ch_ui/README.md)
