# 05 — Kubernetes victim telemetry

The `k3s-vuln` VM is the prepared defender-side evidence producer. The canonical blueprint and prebuilt victim template install the components; participants inspect the evidence rather than manually installing k3s, Tetragon, Vector, or audit policy.

## Evidence sources

```text
k3s API server ───── Kubernetes audit JSON ─┐
Tetragon ─────────── process/socket JSON ───┼─ victim Vector ─► central Vector
selected containers ─ native CRI logs ─────┘                     │
                                                                 ▼
                                                           ClickHouse IR
```

| Source | What it can establish |
|---|---|
| Kubernetes audit | API user, verb, resource, namespace/object, response code, and request metadata |
| Tetragon | Container/process execution, parent lineage, credentials/namespaces, and bounded socket observations |
| CRI/container logs | Application output from selected scenario workloads |
| Vector internal | Transport health, buffering, and delivery state |

No single source proves the whole attack. The workshop compares independent records and states the correlation method explicitly.

## Prepared telemetry boundary

The range keeps k3s' standard Flannel networking and runs standalone Tetragon. Bounded tracing policies focus on workshop-relevant namespaces and events rather than recording every syscall. Kubernetes API audit and Tetragon runtime telemetry remain independent evidence sources.

The victim Vector agent:

- tails native local records;
- adds `source_type`, `source_host`, and `range_id`;
- checkpoints files and buffers on disk;
- sends acknowledged Vector protocol traffic to `clickhouse-ir` on TCP/6000.

Parsing and ClickHouse credentials remain central; the victim does not write directly to ClickHouse.

## Participant checks

Use CH-UI dashboards in module 03 to confirm that the victim is producing fresh evidence before starting an experiment. After the run, use module 08 to filter by run ID and compare:

- Kubernetes API actions;
- Tetragon process lineage;
- attacker network connections;
- victim container/application output;
- expected versus missing source coverage.

Time-window membership establishes that an untagged event occurred inside the measured run. Namespace, pod, process, network tuple, and timestamp correlations strengthen an association but should not be described as causality without supporting evidence.

## Known reliability gate

A Tetragon DaemonSet being `Ready` is not enough. Deployment validation must also establish fresh host-export and ClickHouse events using the role's bounded ephemeral canary.

## Reference

- [`../ansible/roles/ludus_k3s_goat/README.md`](../ansible/roles/ludus_k3s_goat/README.md)
