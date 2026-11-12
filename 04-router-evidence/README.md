# 04 — Router PCAP and Zeek evidence

The range router is the stable observation point between the Kali attacker on VLAN 20 and Kubernetes Goat on VLAN 30. Participants do not install or administer the router tooling: the Source-owned router template already contains pinned Zeek, Vector, tcpdump, and time synchronization dependencies.

## Run-bounded evidence flow

```text
kali-caldera ── routed experiment traffic ──► k3s-vuln
                         │
                         ▼
                  router victim-facing NIC
                         │
                    bounded tcpdump
                         │
             sealed PCAP + SHA-256 manifest
                         │
                  offline Zeek processing
                         │
              Zeek JSON + artifact manifest
                         │
                    router Vector
                         │
                    ClickHouse IR
```

Zeek is not a continuously running network monitor in this workshop. It processes the sealed PCAP after the run stops. Vector remains active and forwards the resulting Zeek JSON and PCAP manifest. The binary PCAP stays on the router for explicit instructor export and retention handling.

## Participant contract

The experiment command on `clickhouse-ir` coordinates capture. Participants should not need a separate router workflow, but the lifecycle is conceptually:

```text
experiment start
→ start bounded capture with the same run ID
→ execute the prepared attack
→ stop capture
→ seal/hash PCAP
→ process PCAP with Zeek
→ send Zeek and manifest evidence
→ complete the run
```

The capture is limited by time, file size, available disk, and a single-active-capture lock. Start is rejected when the router clock is not synchronized.

## Interface selection

The implementation does not hardcode `ens21`. During deployment, the role asks the router which interface routes to:

```text
10.<range-number>.30.30
```

The current topology normally resolves that victim-facing path to `ens21`, but route-based discovery protects the workflow if interface naming changes.

## Evidence to inspect

After completion, use the run ID in CH-UI to inspect:

- the sealed PCAP artifact manifest;
- capture start/end times, packet and byte counts;
- PCAP SHA-256;
- Zeek connection UIDs and five-tuples;
- Zeek HTTP, DNS, and TLS metadata when present;
- source host and explicit run/artifact identity.

The manifest proves the identity and integrity metadata recorded by the capture workflow. Zeek describes observed network traffic; it does not independently prove that a victim-side process or Kubernetes action occurred.

## Reset-safe replay

The router is outside Ludus workload snapshots. Before participant turnover, the broker verifies forwarding, clears router-local evidence state, and restores the workloads. An instructor may replay a sealed artifact after verifying its hash only as bounded troubleshooting before that cleanup. Replay preserves the original run and artifact IDs and refuses reused replay IDs or artifacts already present in ClickHouse.

Participants observe replay results rather than operating the replay command.

## Reference

- [`../ansible/roles/ludus_router_evidence/README.md`](../ansible/roles/ludus_router_evidence/README.md)
