# 01 — Virtualization and the Ludus Range

This workshop stage introduces virtualization choices, Ludus concepts, and the reproducible VibeRange foundation. The participant outcome is an assigned range containing an isolated router plus three healthy workload VMs with verified addressing, network policy, and reset behavior.

## Authoritative definition

The authoritative range definition is the Ludus Source at the repository root and its single blueprint:

```text
source.yml
blueprints/viberange/blueprint.yml
blueprints/viberange/range-config.yml
blueprints/viberange/requirements.yml
ansible/roles/
```

## Starting topology

| VM | VLAN | Starting size | Stable role |
|---|---:|---:|---|
| Ludus router | all range VLANs | 4 GB RAM / 2 vCPU | Routing, policy, later router evidence |
| `clickhouse-ir` | 10 | 10 GB RAM / 3 vCPU | Analysis and evidence services |
| `kali-caldera` | 20 | 6 GB RAM / 2 vCPU | Controlled red-side orchestration |
| `k3s-vuln` | 30 | 8 GB RAM / 3 vCPU | Intentionally vulnerable Kubernetes target |

The production blueprint uses Source-owned router, analysis, attacker, and victim templates. Instructors build and validate templates before assigning ranges; participants do not manage images.

## Instructor-only Source installation

Participants do not register Sources, install blueprints, edit range configuration, or handle repository credentials. The platform administrator performs these steps before the workshop.

Install the public Git Source from an immutable release tag:

```bash
ludus source add \
  https://github.com/Mastermjr/viberange-workshop.git \
  --id viberange \
  --ref <immutable-release-tag> \
  --all \
  --global

ludus blueprint info viberange/viberange
```

The instructor creates, completely deploys, validates, and assigns each participant range from the installed blueprint:

```bash
ludus -r <participant-range-id> range create \
  --name "VibeRange" \
  --from-blueprint viberange/viberange
ludus -r <participant-range-id> range deploy
```

## Participant inspect workflow

The reservation broker delivers only a fresh generation-bound WireGuard profile for the assigned slot. The instructor provides any approved range-local application credentials separately. Participants do not receive Ludus, Proxmox, host, or router credentials.

After connecting WireGuard, open the assigned JupyterLab terminal and inspect the analysis VM with ordinary Linux commands such as `hostname`, `ip address`, and `systemctl status`. Use the provided topology to identify the router, analysis, attacker, and victim roles. Range creation, Source management, deployment, and reset remain instructor operations.

## Stage validation

Before continuing, verify:

- router and all three workload VMs exist;
- VM templates, CPU, memory, VLANs, and host offsets match the blueprint;
- documented administration paths work;
- attacker-to-victim training traffic traverses the router;
- unspecified inter-VLAN paths are denied;
- the Source revision and blueprint version are recorded;
- the documented testing/reset operation returns the range to baseline.

Do not execute the Caldera operation in this stage. Later modules introduce the already-deployed evidence sources and controlled purple-team workflow.

## References

- [`../docs/architecture.md`](../docs/architecture.md)
- [`../docs/participant-deployment-modes.md`](../docs/participant-deployment-modes.md)
- [`../docs/participant-isolation.md`](../docs/participant-isolation.md)
