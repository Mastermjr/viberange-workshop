# 07 — Caldera attacker orchestration

`kali-caldera` hosts the prepared MITRE Caldera operation used by the workshop. The instructor deploys and validates it through the canonical VibeRange Source; participants do not install Caldera, extract API keys, register agents, or create arbitrary operations.

## Participant access

While connected to the assigned WireGuard profile, open:

```text
http://10.<range-number>.20.20:8888/
```

Log in with username `admin` and password `admin`. The broker delivers only the WireGuard profile; WireGuard policy permits only the assigned client to reach its range-local Caldera UI.

Caldera is primarily an attacker-intent and execution-ground-truth interface in this workshop. The experiment CLI in module 08 starts and stops the prepared operation so the router capture, run ledger, and Caldera operation share one run identity.

## Prepared operation

The checked-in `k8s-goat-attack` scenario is a seven-link atomic adversary spanning the Cyber Kill Chain from discovery through a bounded host-escape demonstration and a non-destructive cluster-admin namespace query.

Before execution, participants should review:

- the adversary and ordered abilities;
- the range-specific fact source;
- the target and callback boundaries;
- ability requirements and expected results;
- the distinction between a successful Caldera link and independent defender evidence.

Do not substitute unrelated abilities or targets. The operation is authorized only against the assigned Kubernetes Goat victim.

## During and after the run

Use Caldera to observe link state, delegated and completed timestamps, commands, results, and status. The participant experiment CLI waits for all seven expected links and exports terminal operation/link ground truth into ClickHouse.

The export records:

- operation and adversary IDs;
- stable ability and link IDs;
- agent identity;
- delegated and finished times;
- bounded command and result data;
- link status;
- the VibeRange run ID.

Vector ingests these records into `ir.raw_events`; materialized views project them into `ir.caldera_operations` and `ir.caldera_links`. The run ledger stores the exact Caldera operation ID.

## Correlating attacker intent with evidence

Caldera supplies the attack plan and execution receipt. A link status of `0` means the agent reported successful command completion; it does not independently prove the target-side effect.

Compare each link with the independent sources appropriate to that action:

- Kali auditd for attacker-host execution;
- router PCAP and Zeek for observed network traffic;
- Kubernetes audit for API requests and authorization results;
- Tetragon for victim process and runtime activity;
- selected container logs for application behavior.

The reconstruction notebook preserves exact identifier joins and labels time-window relationships as candidate correlations rather than causality. Missing or contradictory evidence remains visible.

## Reset boundary

Completing an experiment exports Caldera ground truth and seals evidence. Participant turnover is a separate instructor operation that revokes WireGuard, cleans router evidence state, restores workload snapshots, and verifies the clean baseline.

The prepared scenario does not install persistence or retrieve Kubernetes secret contents.

## Real-world context

[`REAL-WORLD-CONTEXT.md`](REAL-WORLD-CONTEXT.md) links the privileged-container, host-mount, and Kubernetes RBAC techniques to incident-response and threat-hunting literature. The workshop chain is a reproducible composite scenario, not a claim that one published incident followed the exact same sequence.

## References

- [`../06-k8s-goat/README.md`](../06-k8s-goat/README.md)
- [`../08-experiment-framework/README.md`](../08-experiment-framework/README.md)
- [`../docs/architecture.md`](../docs/architecture.md)
