# Ludus WireGuard-only lockdown procedure

## Safety boundary

This procedure does not update packages, install microcode, reboot Proxmox, or change
host SSH, Tailscale, Proxmox networking, or host firewall policy. WireGuard key
rotation/reassignment belongs to the deployment's reservation broker and is not
duplicated here.

Keep participant access closed until all five profiles pass the final matrix.
Real credentials and management CIDRs remain in protected operator state.

## Execution order

### 1–2. Back up and set Ludus controls — operator/root checkpoint

Repository helper:

```bash
sudo EXPECTED_HOST="$(hostname -s)" scripts/apply-ludus-control-plane-lockdown.sh --check
sudo EXPECTED_HOST="$(hostname -s)" scripts/apply-ludus-control-plane-lockdown.sh --apply
```

The apply mode:

1. verifies it is running as root on the explicitly configured Ludus host;
2. requires `ludus` and `ludus-admin` to be active;
3. backs up `/opt/ludus/config.yml` and `/opt/ludus/db` under a mode-`0700`
   timestamped directory;
4. sets `prevent_user_ansible_add: true` and `expose_admin_port: false` without
   printing the rest of the credential-bearing config;
5. restarts only `ludus` and `ludus-admin`;
6. requires both services to recover and the configured admin port to listen
   only on loopback;
7. restores the old config and attempts a service restart if validation fails.

Immediately afterward, the operator verifies the existing instructor tunnel and
an administrator-only read operation. Do not proceed if the tunnel or API is
unhealthy. The script cannot prove remote reachability from the operator's
workstation.

### 3. Restrict Ludus state files — operator/root checkpoint

First inspect rather than assuming paths or service ownership:

```bash
systemctl show -p User -p Group ludus ludus-admin
stat -c '%a %U:%G %n' /opt/ludus/config.yml /opt/ludus/db
find /opt/ludus/db -maxdepth 1 -printf '%m %u:%g %p\n'
```

If the live units confirm the expected `ludus` service identity, set the config
to `0600`, database directory to `0700`, and database files to `0600`, preserving
required ownership. Restart the two Ludus services and repeat the tunnel/API
check. Do not recursively change ownership based only on repository assumptions.

### 4. Rotate and retain infrastructure credentials — operator checkpoint

For `user1`–`user5`:

- generate a new Ludus API key, proving the prior key is rejected;
- rotate the PAM/Proxmox password;
- store new values only in the protected operator credential store;
- do not put secrets in command arguments, shell history, logs, issue trackers,
  chat, Git, handoff records, or test reports;
- never give these values to participants.

This phase does not rotate WireGuard keys. That lifecycle belongs to the broker.

### 5. Render and apply per-range management blocks

#### Mandatory live range-number overlap gate

Repository range numbers are examples or stale inventory, never deployment
truth. Immediately before every rollout, resolve each assigned range number
from the authenticated Ludus API and derive its prefix as
`10.<live-range-number>.0.0/16`.

Fail closed before rendering if:

- two participant slots resolve to the same range number or prefix;
- a slot has no live range number;
- any participant `/16` overlaps a host-connected, management, storage, OOB,
  tailnet-routed, DNS/NTP/cache, or other protected site network;
- the assigned `/16` overlaps any entry intended for that range's
  `always_blocked_networks`;
- the live mapping changes between rendering and application.

Record conflicting range numbers in the Ludus host's
`reserved_range_numbers` before creating replacement users/ranges. Existing
conflicting ranges must be moved/recreated through the approved lifecycle; a
reserved-number setting does not repair an already allocated range.

This gate is mandatory because a participant `/16` can overlap narrower
host-connected management or storage networks. Quarantine and recreate any
conflicting range at a non-overlapping number, update every range firewall, and
reserve the unsafe number before future user or range creation.

Use one protected blocked-network JSON document per range. It must contain the
narrowest correct CIDRs for:

- the Proxmox management host/interfaces;
- site management, storage, and out-of-band networks;
- tailnet-routed destinations and the external Tailscale subnet router;
- every other participant range prefix.

Do not block the assigned `10.<range-number>.0.0/16`, the router's required WAN
next hop, or required DNS/NTP/package destinations.

Example for each inactive range:

```bash
scripts/render-secure-range-config.sh \
  --range-number <number> \
  --blocked-networks /protected/viberange/<range>-blocked-networks.json \
  --wireguard-client-octet <live-user-number> \
  --output /protected/viberange/<range>-range-config.yml

ludus -r <range> range config set \
  -f /protected/viberange/<range>-range-config.yml
ludus -r <range> range deploy
```

Apply and validate one inactive canary range first. Firewall regeneration can
briefly drop that range's forwarded traffic but does not change host Tailscale.
Stop if required DNS, NTP, package access, or an approved workshop flow fails.

### 6. Confirm the blueprint's participant policy

For every rendered configuration require:

- `wireguard_vlan_default: REJECT`;
- WireGuard access only to approved participant services (currently CH-UI
  TCP/3488, Jupyter TCP/8889, and Caldera TCP/8888);
- `inter_vlan_default: REJECT`;
- only the documented experiment and Vector flows;
- non-empty site-specific `always_blocked_networks`.

A participant profile may contain a route to the Ludus WireGuard host address.
Removing that route is useful client-side least privilege but is not a security
boundary because a participant can add it back. The final test must therefore
probe host management ports explicitly.

### 7. WireGuard rotation and lease lifecycle — broker-owned

The deployment broker's acceptance contract must prove that the previous
profile no longer handshakes before a slot becomes available. This repository
consumes that result; it does not maintain a second rotation implementation.

### 8. Independent profile acceptance — operator + separate client

Test from a workstation connected with exactly one participant profile at a
time. Do not run the negative matrix from the Proxmox host or instructor tunnel.
For each profile record only destination class, port/protocol, expected result,
observed result, and timestamp; keep private addresses out of participant-visible
reports.

Required allows:

- assigned CH-UI TCP/3488;
- assigned Jupyter TCP/8889;
- assigned Caldera TCP/8888;
- approved exercise and telemetry paths tested from their appropriate guest
  VLANs;
- required DNS, NTP, and package access.

Required denials:

- Proxmox host and every host bridge/interface address;
- host TCP/22, 8006, 8080, 8081, and 3128;
- site management, storage, OOB, and tailnet-routed destinations;
- the Tailscale subnet router/gateway;
- every other participant range;
- attacker/victim VLAN services not explicitly exposed to participant
  WireGuard.

A timeout alone is not sufficient evidence when the target may simply be down.
Where possible, prove the destination is healthy from the instructor path, then
prove the participant profile is denied. After each profile, disconnect it and
confirm routes/interfaces are removed before importing the next one.

## Go/no-go

Go only when phases 1–6 are complete, the broker reports successful old-profile
revocation, and every profile passes both positive and negative tests. Any
unexpected management-plane success, cross-range success, stale-profile
handshake, or required-service failure is a no-go and quarantines that slot.
