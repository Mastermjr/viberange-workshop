# Instructor deployment modes and participant handoff

Complete and progressive profiles are implemented and validated. Initial deployment, lifecycle reset, and participant handoff remain instructor responsibilities.

## Responsibility boundary

The instructor/platform workflow owns:

- Source and blueprint installation;
- template builds;
- range creation and initial deployment;
- complete versus progressive role application;
- service/network validation;
- participant assignment;
- testing reset, cleanup, and reassignment.

A participant receives only:

- a fresh WireGuard profile for the assigned range;
- approved guest/application credentials;
- the supported terminal/browser connection instructions;
- access to the prepared range and VM-local sudo where the workshop requires it.

Participants do not receive Ludus API keys, PAM/Proxmox passwords, host SSH
credentials, Source or blueprint access, or cross-range access. The WireGuard
profile is a secret because it contains a client private key. Instructor
automation retains the protected Ludus administrator credential.

## One canonical blueprint

Use one Git-authoritative blueprint containing:

- the router and three workload VMs;
- VLANs, addressing, resources, and network policy;
- every versioned workshop role;
- explicit same-VM and cross-VM dependencies;
- no participant credential or experiment run identity.

Do not maintain separate hand-edited complete and workshop topologies.

## Complete instructor deployment

The standard workshop handoff is a fully deployed range. Before range creation,
the instructor renders the installed canonical configuration with the protected
site CIDR list:

```bash
scripts/render-secure-range-config.sh \
  --range-number <assigned-range-number> \
  --blocked-networks /protected/viberange/blocked-networks.json \
  --wireguard-client-octet <assigned-user-number> \
  --output /protected/viberange/<participant-range>-range-config.yml

ludus -r <participant-range> range create --name VibeRange
ludus -r <participant-range> range config set \
  -f /protected/viberange/<participant-range>-range-config.yml
ludus -r <participant-range> range deploy
```

The protected JSON contains the exact Proxmox and site management,
storage, out-of-band, tailnet-routed and Tailscale gateway CIDRs. Never apply
the generic Source blueprint directly to a production participant range because
it intentionally contains no private site CIDRs.

Before assignment, the instructor verifies VM/service health, required
templates, network paths (including management-network denials), analyst
interfaces, and the pinned Source release.

## Progressive instructor deployment

Progressive deployment remains useful while building or teaching component boundaries:

```bash
ludus -r <participant-range> range deploy \
  --only-roles <comma-separated-cumulative-role-set>
```

The versioned stage manifest is `config/viberange-stages.json`. Stage wrappers remain instructor-maintained and must enforce dependencies, release identity, serialization of clone operations, and safe retry behavior.

Progressive deployment is not a reason to ask participants to type internal role names or repair failed provisioning.

## Participant handoff checks

Before giving a range to a participant:

1. range state is `SUCCESS` and all expected VMs are powered;
2. Source/blueprint/template versions match the workshop release;
3. ClickHouse, Vector, CH-UI, Jupyter, Caldera, k3s, Kubernetes Goat, Tetragon, detections, and router evidence services pass their gates;
4. participant terminal and browser paths are verified;
5. the new WireGuard profile reaches only explicitly approved assigned-range services;
6. host management networks, management ports and every other participant range are denied;
7. the previous WireGuard profile is proven unusable;
8. no stale experiment is active;
9. baseline/reset state and evidence-retention policy are recorded.

## Five-user lifecycle test

The reusable participant pool remains `user1` through `user5`. Credentials stay in protected operator state and are delivered out of band.

The lifecycle test should:

1. create or reuse non-admin slots while retaining their API/PAM credentials only in protected operator state;
2. prepare and deploy one securely rendered blueprint-backed range per slot;
3. generate one fresh WireGuard profile per assignment generation;
4. verify positive and negative range isolation with every WireGuard profile;
5. validate complete and progressive instructor deployment on disposable ranges;
6. test bounded concurrency without concurrent VM clone races;
7. revoke WireGuard before testing/reset and reassignment;
8. dry-run then execute scoped cleanup;
9. confirm old WireGuard profiles and stale snapshots, credentials, assignments, or run state cannot reach the next participant.

Capacity validation is a separate operator responsibility and must be repeated for the target infrastructure.

## Acceptance

The handoff model passes when:

- the instructor can reproducibly prepare complete equivalent ranges;
- participants begin with healthy assigned environments;
- each participant can use only a fresh assigned-range WireGuard profile;
- participants can run the prepared experiment without Ludus or infrastructure credentials;
- VM-local sudo does not grant Source, Proxmox, or cross-range control;
- reset/reassignment removes prior participant state according to retention policy;
- cleanup is idempotent, scoped, auditable, and cannot delete unrelated ranges.
