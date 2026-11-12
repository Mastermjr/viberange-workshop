# Participant isolation and access boundary

## Decision

The workshop uses instructor-managed Ludus ranges. Participants receive only a
unique WireGuard profile plus approved guest/application credentials for their
assigned `user1`–`user5` range.

Participants do not receive:

- Ludus API keys or the Ludus management URL;
- Proxmox/PAM passwords;
- host SSH credentials;
- direct Proxmox, SPICE, Source, blueprint, template or Ansible management
  access.

Instructor automation uses a protected Ludus administrator credential for inventory, deployment, reset, power, and verification.

## Enforcement

The canonical blueprint declares WireGuard-only participant access and requires
site-specific blocked networks. `scripts/render-secure-range-config.sh` injects
the protected management CIDR list into each production range configuration
without committing those CIDRs. Participant deployment, reservation and
administration documentation now treats Ludus credentials as operator-only.
The guarded root helper and ordered no-reboot procedure are documented in
[`ludus-lockdown.md`](ludus-lockdown.md). Each
operator must execute the host checks and complete an independent allow/deny
matrix with freshly issued profiles before participant handoff.

## Required controls

### Credential handling

- Rotate existing `user1`–`user5` API keys and PAM/Proxmox passwords before the
  workshop; retain them only in protected operator state.
- Never include those values in participant handoffs, chat, Git, issue trackers,
  reports, process arguments or generated range artifacts.
- Generate or retrieve one WireGuard profile per assignment generation.
- Treat the complete WireGuard profile as a secret because it contains a client
  private key.
- Revoke the previous profile before resetting/reassigning a slot.
- Do not mark a slot available until the old profile is proven unusable and the
  new baseline passes.

### Ludus defense-in-depth

Set on the host:

```yaml
prevent_user_ansible_add: true
expose_admin_port: false
```

Participants do not receive API keys, but disabling non-admin role/collection
installation limits impact if a credential is accidentally disclosed.

Ludus also installs a broad assigned-user WireGuard access grant by default.
Every production range must override it with a catch-all REJECT scoped to that
user's live WireGuard client octet, followed in configuration order by the
explicit CH-UI/Jupyter allows. Ludus inserts later user rules above earlier
ones, yielding approved allows, then scoped deny, then the broad built-in grant.
Never use an unscoped `vlan_src: wireguard` ACCEPT rule.

Deny interactive SSH authentication for the generated `lab-participant-*` PAM
accounts, or enforce host-wide key-only SSH after validating operator recovery
access. Ludus internal deployment behavior must pass after this change.

Restrict `/opt/ludus/config.yml` and Ludus database files to the service and
root administrative identities. Keep TCP/8081 loopback-only and TCP/8080
unreachable from participant networks.

### Instructor lifecycle

For every assignment:

1. revoke prior participant access;
2. restore/redeploy the approved router, analysis, attacker and victim baseline;
3. verify the pinned Source, blueprint, templates and role graph;
4. power and validate all four VMs;
5. issue a fresh WireGuard profile through the protected handoff workflow;
6. verify participant-facing services through that profile;
7. start the lease only after successful delivery.

At expiry, revoke WireGuard before reset and preserve only sanitized failure
evidence.

## Management-network blocks

Ludus provides a separate router/bridge per user and the blueprint defaults
inter-VLAN and WireGuard-to-VLAN traffic to reject. That does not by itself
prove that guest egress cannot reach host, LAN, storage, out-of-band or
Tailscale-routed management networks.

The current blueprint uses:

```yaml
network:
  external_default: ACCEPT
```

Therefore every generated production range configuration must also populate:

```yaml
network:
  always_blocked_networks:
    - <proxmox-management-host-or-subnet>
    - <site-management-network>
    - <storage-network>
    - <out-of-band-management-network>
    - <tailnet-routed-destination-network>
    - <tailscale-subnet-router-or-gateway>
```

Do not commit real private management CIDRs to the generic Source. Store the
site-specific list in protected instructor configuration and inject it into the
range configuration before creation/deployment. The rendered configuration
must be retained only in protected operator state if it contains sensitive
network details.

Use the narrowest correct CIDRs. Do not block the participant's own range
prefixes or required DNS/NTP/package endpoints accidentally.

## Required network tests

Run the complete matrix with each `user1`–`user5` WireGuard profile and from the
analysis, attacker and victim VLANs.

Required denials:

- Proxmox host and all host bridge/interface addresses;
- TCP/22, 8006, 8080, 8081 and 3128 on the host;
- site management, storage, and out-of-band networks;
- tailnet-routed networks and their subnet router/gateway;
- every other participant range;
- participant WireGuard access to VLANs/ports not explicitly allowed.

Required allows:

- assigned participant WireGuard to CH-UI TCP/3488;
- approved participant-facing services added explicitly by the workshop;
- attacker VLAN to victim VLAN for the bounded exercise;
- attacker/victim Vector delivery to the assigned analysis VLAN;
- required guest DNS, NTP and package/image access.

A successful allowed connection does not prove isolation. Capture both positive
and negative results with source location, destination class, expected result
and observed result, without recording sensitive addresses in participant-
visible reports.

## Documentation contract

Keep these interfaces synchronized with the access policy:

- `docs/participant-deployment-modes.md`;
- `config/participant-pool.json` semantics and handoff tooling;
- lifecycle/reset reports and acceptance tests.

Participants must not configure or use a Ludus API key. Their workflow begins
after instructor deployment and uses the assigned WireGuard profile only.
