# Ludus and Proxmox Prerequisites for VibeRange

Status: required instructor prerequisite checklist

This document separates one-time Ludus/Proxmox administration from participant Stage 1 work. It contains no credentials or environment-specific secret values.

## Responsibility boundary

| Responsibility | Instructor/platform administrator | Participant |
|---|---:|---:|
| Install and maintain Proxmox/Ludus | Yes | No |
| Configure Git access for the private Source | Yes | No |
| Install/build shared templates | Yes | Observe/verify |
| Confirm host capacity and storage | Yes | Record assigned limits |
| Create and assign a range from the supplied blueprint | Yes | No |
| Deploy and inspect an assigned range | Support | Yes |
| Modify Proxmox bridges/firewall/storage | Yes | No |
| Inspect range topology and validate policy | Support | Yes |
| Handle repository, Ludus, or Proxmox credentials | Yes | No |

## Required platform information

The access epic must record sanitized values for:

- Ludus server and CLI version;
- Ludus edition and router-role capability;
- Proxmox cluster/node names needed for scheduling decisions;
- VM and ISO storage pools;
- available CPU, memory, and storage headroom;
- maximum supported concurrent workshop ranges;
- installed and built template names;
- Source/blueprint command support;
- snapshot/testing-mode support and policy;
- range network bridge and router interface naming relevant to later capture.

Do not record API keys, passwords, private keys, tokens, or sensitive management addresses in this repository or issue trackers.

## Capacity envelope

Starting allocation per range:

| Component | RAM | vCPU |
|---|---:|---:|
| Router | 4 GB, 2 GB minimum | 2 |
| Analysis | 10 GB | 3 |
| Attacker | 6 GB | 2 |
| Victim | 8 GB | 3 |
| **Requested total** | **28 GB** | **10** |

The total excludes Proxmox/Ludus services, filesystem cache, template builds, snapshot growth, packet captures, ClickHouse data, Kubernetes images, and temporary deployment overhead. Overcommit policy and the supported concurrent-range count must be established by the platform administrator through staged load testing in the target environment.

Before announcing a concurrent-range count, measure:

- idle and active memory per range;
- peak CPU during Caldera, Zeek replay, Tetragon, and ClickHouse queries;
- base clone storage and copy-on-write growth;
- PCAP and ClickHouse growth for one bounded run;
- snapshot storage growth;
- template-build temporary storage;
- time to deploy and reset ranges concurrently.

## Required templates

The current VibeRange Source expects four Source-owned templates:

```text
viberange-router-debian12-v1-template
viberange-clickhouse-ir-debian12-v1-template
viberange-kali-caldera-v1-template
viberange-k3s-vuln-debian12-v1-template
```

The Kali template is derived from the canonical Ludus Kali definition and bakes
the desktop, generic attacker prerequisites, auditd, and pinned Vector only. It
contains no Caldera, range, credential, run, or telemetry-pipeline state. The
router template preinstalls generic pinned Zeek, Vector, tcpdump, and NTP
dependencies. The victim template preinstalls pinned k3s, Helm, Vector,
Kubernetes Goat source, the Tetragon chart, and digest-resolved image archives,
but never initializes k3s. Range-specific identity, addressing, API keys,
Caldera content, cluster state, telemetry destinations, and service
configuration remain in Source roles. Template names must match
`ludus templates list` exactly.

Instructor checks:

```bash
ludus templates list
```

Build only missing required templates using the syntax supported by the installed Ludus version. Template builds should finish before class because they can consume substantial time, bandwidth, CPU, and storage:

```bash
ludus templates build -n viberange-router-debian12-v1-template
ludus templates build -n viberange-clickhouse-ir-debian12-v1-template
ludus templates build -n viberange-kali-caldera-v1-template
ludus templates build -n viberange-k3s-vuln-debian12-v1-template
```

Build the templates serially on the target host. The victim build downloads and archives its pinned image set and therefore needs more time and temporary storage than the router build.

## Template-build network prerequisites

Ludus/Packer template builds need more than general outbound internet access. A validated deployment required the Proxmox cluster firewall and build network to permit the following on its Ludus NAT/build bridge (the bridge name is environment-specific):

| Traffic | Purpose |
|---|---|
| UDP/67 | DHCP during template boot |
| UDP/53 | DNS |
| TCP/53 | DNS fallback/large responses |
| TCP/8000–8999 | Packer HTTP server for unattended installation assets |

These are known environment findings, not universal permission to open the ports on every interface. Confirm the actual bridge, source/destination direction, and Ludus documentation for the installed version. Scope rules to the template-build network and Ludus host rather than exposing them broadly.

A stalled build should be diagnosed through Ludus template logs and observed DHCP/DNS/Packer reachability before changing firewall policy.

## Proxmox storage prerequisites

Confirm before deployment:

- VM disks and templates use a storage pool with sufficient space and snapshot support;
- ISO storage has room for required installer images;
- the selected pool supports the clone mode used by Ludus;
- TRIM/discard behavior is understood and tested;
- snapshot retention cannot exhaust the host;
- PCAP and ClickHouse growth have explicit bounds;
- template builds do not land on a nearly full directory-backed store by accident.

Storage pool names and formats are environment-specific. Remeasure free space and snapshot behavior on the target host rather than copying settings from another deployment.

## Public Source access

Register the public Source using its credential-free HTTPS URL:

```bash
git ls-remote https://github.com/Mastermjr/viberange-workshop.git
```

Pin production installations to published immutable tags rather than branches or raw commit IDs. Record the commit resolved by every tag and never move a release tag. No repository credential or deploy key is required for the public Source.

## Ludus Source and blueprint prerequisites

The installed Ludus version must support:

```text
ludus source add
ludus source list
ludus blueprint info
ludus range create --from-blueprint
```

Before class, validate the release from a clean Ludus user or equivalent isolated catalog state:

```bash
ludus source add <repository-url> --id viberange --ref <immutable-release-tag>
ludus source add viberange --blueprints viberange
ludus blueprint info viberange/viberange
```

Confirm that every vendored role is discoverable through the installed Source.

### Required control-plane lockdown

Production participant ranges require these host-global settings:

```yaml
# /opt/ludus/config.yml
prevent_user_ansible_add: true
expose_admin_port: false
```

Use the guarded root helper before participant deployment:

```bash
sudo scripts/apply-ludus-control-plane-lockdown.sh --check
sudo scripts/apply-ludus-control-plane-lockdown.sh --apply
```

Afterward require `ludus` and `ludus-admin` to be active, the configured admin
port (normally TCP/8081) to be loopback-only, and the instructor API tunnel to
complete an authenticated read. Protect `config.yml` as `0600`, database
directories as `0700`, and database files as `0600` under the verified service
identity.

This is a host prerequisite, not an Ansible role in the range. The blueprint
records the required values as extension metadata so deployment tooling can
fail closed without granting a guest role permission to mutate the Ludus host.

## Router capability prerequisites

Record whether the installed Ludus edition supports user-defined roles attached directly to the router. If it does, later releases may attach the router evidence role through the blueprint. If it does not, the router epic must provide a community-compatible idempotent instrumentation step.

In either case, establish:

- router VM template and resource allocation;
- interface carrying attacker/victim routed traffic;
- interface-name stability across range creation;
- disk location and quota for run-bounded PCAP;
- path from router-generated Zeek JSON to central Vector;
- how router state participates in reset/testing mode.

Do not install packet tooling during Stage 1; this is a capability check for the later router stage.

## Network-isolation prerequisites

The blueprint starts with:

```text
inter-VLAN default: REJECT
external default: ACCEPT during deployment
WireGuard/client-to-VLAN default: REJECT
explicit VLAN 20 → VLAN 30 authorized training path
```

Before class, determine:

- management networks that must be listed as always blocked;
- approved operator path through Ludus/Tailscale/WireGuard;
- whether testing mode blocks internet as expected;
- DNS/NTP behavior while internet is blocked;
- whether package/image caches are available for offline stages;
- exact later-stage Vector and callback ports before adding those rules.

Validation must include denied-path tests. A successful allowed connection alone does not prove isolation.

## Non-destructive instructor preflight

Run these checks without deploying or deleting a range:

```bash
# CLI and authenticated API access
ludus --help
ludus range list

# Required catalog capabilities
ludus source list
ludus blueprint list
ludus templates list

# Source metadata from a clean registration or development upload
ludus source list viberange --catalog
ludus blueprint info viberange/viberange
```

Then verify outside Ludus:

- free Proxmox storage and snapshot headroom;
- available host memory/CPU under expected concurrency;
- Git access as the `ludus` user;
- DHCP, DNS, and Packer HTTP behavior on the template-build network;
- no stale ranges or snapshots consume the workshop allocation.

Commands that mutate firewall, storage, templates, users, or ranges remain administrator actions and should not be hidden inside participant preflight scripts.

## Failure handling

The instructor runbook must include recovery for:

- Source clone/authentication failure;
- Source metadata or blueprint schema rejection;
- missing/unbuilt template;
- DHCP/DNS/Packer template-build stall;
- insufficient storage;
- range deployment role failure;
- snapshot creation/revert failure;
- participant range naming collision;
- partial range creation after blueprint application failure.

Recovery should preserve logs and avoid broad destructive cleanup. If a failed blueprint application creates a range record, use the retry command reported by Ludus or remove the specific failed range only after collecting diagnostics.

## Readiness gate

The platform is ready for Stage 1 only when:

1. the authorized operator can access Ludus noninteractively;
2. the pinned private Source can be read by the Ludus service account;
3. Source and blueprint commands are supported by the installed version;
4. required standard templates are installed and built;
5. one clean range fits measured capacity and storage limits;
6. known DHCP/DNS/Packer paths pass without broad firewall exceptions;
7. router capability and fallback path are recorded;
8. testing/reset behavior has been demonstrated;
9. no credentials appear in Git, blueprint exports, logs intended for participants, or issue trackers.
