# 09 — Detection review and forensic notebook output

Detection comes after participants execute and investigate the prepared attack. Source evidence remains authoritative; a detection is a query result that must cite the run and source events it matched.

This module also owns the participant-generated Jupyter notebook and HTML reconstruction output after the versioned Caldera operation is complete.

## Part A: Review validated detections

The analysis VM runs the scheduled SQL detection service and stores outcomes in:

```text
ir.detections
```

Every workshop detection must retain:

- experiment run ID;
- rule ID, name, severity, and execution time;
- source dataset and source host;
- singular or grouped source event IDs;
- raw detection payload needed to verify the result.

In CH-UI, compare each hit to its cited source rows. Do not treat Caldera output as victim-side proof and do not treat a missing detection as proof that the source event is absent.

## Scenario-grounded SQL rule set

The initial workshop intentionally uses ClickHouse SQL as its detection language. The prepared `k8s-goat-attack` operation has three validated rules:

| Rule | Authoritative source | Scenario behavior |
|---|---|---|
| Default service account Secret enumeration | Kubernetes audit | `system:serviceaccount:default:default` lists Secrets and receives request/forbidden audit stages |
| Service-account token read | Tetragon | `/usr/bin/cat` reads the mounted Kubernetes service-account token |
| Container chroot into host filesystem | Tetragon | `/usr/sbin/chroot` executes against `/host-system` |

The participant-review queries live under [`queries/`](queries/). Execute one against a completed run with:

```bash
clickhouse-client \
  --param_run_id='<completed-run-id>' \
  --queries-file /opt/viberange-detection/queries/k8s-rbac-probe.sql
```

Each query returns the run ID, source event ID, timestamp, host and Kubernetes context, and the fields that caused the match. Participants validate the rule against their own completed run and inspect every cited source row.

The scheduled YAML forms under [`rules/`](rules/) use the same predicates with a recent-event window. The runner canonicalizes match ordering before fingerprinting so one unchanged evidence set cannot generate duplicate detections merely because ClickHouse returned grouped rows in a different order.

### Translation to KQL, SPL, or EQL

Translating these analytics into KQL, SPL, EQL, Sigma, or a vendor rule format is useful follow-on work, but outside this workshop's initial scope. The portable part is the detection contract:

```text
source dataset + normalized fields + predicate + run identity + cited event IDs + known true-positive evidence
```

A future translation must preserve those semantics and be revalidated against equivalent source records. Syntactic translation alone is not proof that another backend parses, timestamps, groups, or correlates the evidence identically.

## Part B: Generate the forensic notebook

`clickhouse-ir` provides a preinstalled Jupyter environment. While connected to the assigned WireGuard profile, open the range-relative Jupyter URL, choose `01-viberange-reconstruction.ipynb`, supply the completed run ID, and execute all cells.

The notebook queries ClickHouse for:

- run manifest and release identity;
- source coverage and missing-source warnings;
- source-citing timeline;
- sealed PCAP artifact and Zeek connections;
- Caldera operation, links, commands, status, and results;
- Kali auditd ground truth;
- Kubernetes audit actions;
- Tetragon process lineage;
- container/application evidence;
- detections and cited source event IDs;
- integrity and correlation-method checks.

Outputs:

```text
executed notebook (.ipynb)
HTML forensic report
SHA-256 records where publication requires them
```

The notebook is not a second evidence database. It reads deterministic ClickHouse views and produces a reproducible report for one run.

## Reconstruction workshop flow

This is the repeatable flow used to turn an attack operation into a source-citing forensic narrative:

1. **Select one terminal run.** Use the run ID to load the measured boundary, scenario and release identity, and Caldera operation ID.
2. **Measure coverage before interpretation.** Require Kali audit, Kubernetes audit, Tetragon, sealed PCAP, and Zeek evidence; report missing sources instead of hiding them.
3. **Anchor chronology in execution ground truth.** Order Caldera links by delegated time and retain stable ability/link IDs and command status.
4. **Select an action-specific victim record.** Match the expected process, arguments, API verb/resource/user/result, or service log content. Retain its timestamp and source event ID; do not use a busy time window as the proof.
5. **Rank correlation strength.** Exact action fields and shared identifiers are strongest, followed by unique markers. Time proximity is supporting context only.
6. **Render two levels of detail.** Present a compact chronological table, then pair every Caldera step with its exact victim-side log and event ID in the graph.
7. **Evaluate detections as evidence queries.** Show the SQL predicate, attached true-positive rows, and cited source IDs; a Caldera success status is not victim-side proof.
8. **Seal reproducible output.** Generate executed notebook and HTML artifacts and record SHA-256 values.

The mapping of ability IDs to action-specific log predicates is scenario-specific. The flow generalizes to other orchestrators when each step has a defensible victim-side process, API, application, or network record. A time window may narrow the search, but it is not itself evidence that an action occurred.

## Runtime versus notebook content

The analysis template and Jupyter role provide the pinned Python environment, Jupyter service, ClickHouse client libraries, and persistent notebook/output directories on `clickhouse-ir`.

The checked-in Caldera-aware notebook provides the chronological timeline and participant-generated report contract.

## Advanced implementation reference

Detection rules remain SQL plus YAML metadata. The deployable Source role—not participant shell commands—owns scheduled service installation and receiver configuration:

```text
ansible/roles/ludus_detection_runner/
09-detection-and-reporting/queries/
09-detection-and-reporting/rules/
```

The important pattern is:

```text
scheduled SQL
→ threshold/grouping
→ normalized detection result
→ ir.detections with run/source event identity
```

Participants are not expected to install or configure the scheduled detection service during the workshop.

## References

- [`../08-experiment-framework/README.md`](../08-experiment-framework/README.md)
- [`../02-clickhouse/README.md`](../02-clickhouse/README.md)
- [`../08-experiment-framework/notebooks/viberange-reconstruction.ipynb`](../08-experiment-framework/notebooks/viberange-reconstruction.ipynb)
