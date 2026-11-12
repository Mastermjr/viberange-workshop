# 08 — Execute and investigate one bounded experiment

This module is the participant-facing experiment lifecycle. The range is already deployed and healthy. Participants work from `clickhouse-ir`, use the prepared CLI to coordinate the approved attack, and inspect the resulting evidence through CH-UI.

## Participant command surface

The command is installed on `clickhouse-ir`. Start with a unique run ID:

```bash
run_id="workshop-$(date -u +%Y%m%dT%H%M%SZ)"
sudo viberange experiment status
sudo viberange experiment start k8s-goat-attack \
  --scenario-version 1.0.0 \
  --run-id "$run_id"
sudo viberange experiment status
sudo viberange experiment stop --notes 'participant workshop run'
```

If a run cannot complete safely, record the failure explicitly:

```bash
sudo viberange experiment abort --reason '<reason>'
```

The participant uses passwordless VM-local sudo inside the disposable analysis VM. No Ludus, Proxmox, router, or host credential is issued.

The CLI does not expose arbitrary router, ClickHouse, Caldera, or Ludus-administrator commands.

## What `start` coordinates

```text
create run identity and manifest
→ verify synchronized clocks and no overlapping run
→ start bounded router capture using the same run ID
→ initiate/authorize the prepared Kali/Caldera operation
→ report run ID and current state
```

Ludus range creation, power, snapshots, deployment, and destructive reset remain instructor/range-management operations. Starting an experiment does not recreate or reset VMs.

## During the prepared attack

Record the run ID printed by the CLI. Use the dashboards in module 03 to watch:

- source freshness;
- evidence volume by machine;
- Kali/Caldera ground truth;
- Kubernetes API and Tetragon activity;
- router/Zeek evidence after finalization;
- Vector transport health.

The prepared Caldera operation and participant-safe Caldera access are included in the versioned workshop Source. Manual Kali commands may be included as teaching steps, but they must stay inside the assigned range and match the versioned scenario.

## What `stop` coordinates

```text
wait for/stop prepared attack
→ export terminal Caldera operation and links
→ stop router capture
→ seal and hash PCAP
→ process PCAP with Zeek
→ spool Zeek and artifact manifest through Vector
→ wait for defined evidence-drain gates
→ complete the run ledger
```

`abort` records a terminal aborted state and reason. Failure must never be silently converted into `completed`.

## Investigate by run ID

The run ledger exposes source membership through `ir.raw_events_by_run` and the participant-facing views.

### Explicit membership

PCAP manifests and Zeek events contain the run ID in their evidence envelope:

```text
membership_method = explicit_run_id
```

### Time-window membership

Continuously collected auditd, Kubernetes audit, Tetragon, container, and Vector events are associated by range and measured source timestamp:

```text
membership_method = range_time_window
```

Time-window association does not prove causality. Use source event identity, namespace/pod, process lineage, network tuple, Caldera link, and measured time delta when explaining a relationship.

## CH-UI run investigation

Open the shared experiment searches and enter the run ID returned by the CLI. Review:

1. run lifecycle and terminal status;
2. `ir.experiment_coverage` required-source presence;
3. PCAP manifest and Zeek network connections;
4. Caldera operations/links and Kali auditd;
5. Kubernetes API actions;
6. Tetragon process lineage;
7. selected container logs;
8. parse errors and unknown source types;
9. detections and their cited source event IDs after module 09 is complete.

### Recognize evidence gaps

| Observation | Interpretation to test |
|---|---|
| Source absent from coverage | Collector not enabled, no expected event, transport failure, or timestamp outside boundary |
| Source stale before run | Agent/checkpoint/service health problem |
| `ir.parse_errors` row | Evidence retained but typed projection failed |
| Event ingested after stop with explicit run ID | Late delivery that still belongs to the run |
| Untagged event outside time window | Correctly excluded from this run |
| Detection absent | Rule did not match; not proof that source evidence is absent |

Document the evidence supporting the conclusion rather than treating dashboard color as proof.

## Handoff to module 09

After the run is completed and investigated, module 09 covers the installed detections and participant-generated notebook output. The Jupyter runtime and versioned reconstruction notebook are already available on `clickhouse-ir`.

## References

- [`../02-clickhouse/README.md`](../02-clickhouse/README.md)
- [`../03-vector/README.md`](../03-vector/README.md)
- [`../04-router-evidence/README.md`](../04-router-evidence/README.md)
- [`../07-caldera/README.md`](../07-caldera/README.md)
- [`../09-detection-and-reporting/README.md`](../09-detection-and-reporting/README.md)
