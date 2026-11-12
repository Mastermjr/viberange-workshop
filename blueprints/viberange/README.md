# VibeRange Blueprint

This is the single Git-authoritative Ludus blueprint for the VibeRange workshop.

Version `0.11.14` defines:

- a versioned Debian 12 router template with Zeek, Vector, tcpdump, and NTP prerequisites preinstalled;
- a versioned Kali attacker template derived from the canonical Ludus Kali definition, with desktop prerequisites and pinned Vector but no range or experiment state;
- a versioned Debian 12 victim template with pinned k3s, Helm, Vector, Kubernetes Goat source, the Tetragon chart, and intentionally staged container images;
- `clickhouse-ir` on VLAN 10;
- `kali-caldera` on VLAN 20;
- `k3s-vuln` on VLAN 30;
- default-deny inter-VLAN and WireGuard policy with per-client CH-UI, Jupyter, and Caldera access plus explicit experiment and telemetry paths;
- JupyterLab with no application login, relying on the assigned per-client WireGuard rule while retaining XSRF and WebSocket-origin checks;
- a required protected rendering step for site-specific management-network blocks;
- all currently integrated workshop-owned roles and their dependencies;
- authoritative raw evidence plus physical typed source-native ClickHouse tables;
- run-bounded router PCAP capture, sealed manifests, and offline Zeek replay;
- standalone pinned Tetragon, Kubernetes API audit, and buffered victim telemetry;
- explicit experiment run boundaries, sealed run manifests, and query-time evidence membership;
- deterministic timeline/correlation views, source-citing detections, and a reproducible notebook;
- complete and progressive deployment profiles;
- disk-only snapshot and internet-blocking behavior for testing mode.

The blueprint contains no participant credentials or experiment run IDs. Proxmox storage placement is deliberately host-administered rather than embedded in this portable blueprint. Administrators must select storage pools with adequate clone, snapshot, PCAP, ClickHouse, and template-build capacity for their own environment.

## Deployment profiles

The instructor installs the Source, renders each production configuration with
`scripts/render-secure-range-config.sh`, creates ranges, and assigns
participants. Students never edit the Source or blueprint and receive only a
fresh assigned-range WireGuard profile plus approved guest/application
credentials. The generic Source intentionally contains no private site CIDRs
and must not be applied directly to a production participant range.

Complete deployment is one action:

```bash
ludus range deploy
```

Progressive deployment begins with the foundation role and adds cumulative stage role sets through instructor-maintained automation:

```bash
ludus range deploy --only-roles VibeRange.ludus_viberange_foundation
```

See [`../../docs/participant-deployment-modes.md`](../../docs/participant-deployment-modes.md) for the stage contract.

## Required Ludus host settings

Before applying this blueprint to a production participant range, the instructor
must set these global values in `/opt/ludus/config.yml` on the Ludus host:

```yaml
prevent_user_ansible_add: true
expose_admin_port: false
```

They prevent non-admin role/collection installation and keep the Ludus admin
listener loopback-only. They do not disable the normal instructor API.

The blueprint records these requirements under
`ludus_extensions.viberange.required_ludus_host_settings`, but deliberately does
not edit host-global configuration from a range deployment. Apply and validate
them on the Ludus host with:

```bash
sudo EXPECTED_HOST="$(hostname -s)" scripts/apply-ludus-control-plane-lockdown.sh --check
sudo EXPECTED_HOST="$(hostname -s)" scripts/apply-ludus-control-plane-lockdown.sh --apply
```

The helper backs up the config/database, restarts only `ludus` and
`ludus-admin`, requires both services to recover, and requires the admin port to
listen only on loopback. Complete operating instructions and manual validation
are in
[`../../docs/ludus-lockdown.md`](../../docs/ludus-lockdown.md).

Production deployment also requires a rendered, non-empty
`network.always_blocked_networks` and the live Ludus `userNumber` passed as
`--wireguard-client-octet`. The renderer scopes every participant-facing ACCEPT
rule to that single `198.51.100.<userNumber>/32` client. The portable blueprint
uses the non-assignable `.255` sentinel so applying it without rendering fails
closed rather than exposing CH-UI/Jupyter to every WireGuard peer. See
[`../../docs/administration.md`](../../docs/administration.md). A generic Source
blueprint with no private site CIDRs is not production-ready by itself.

## Clean-baseline snapshot sequence

Ludus performs the snapshot and revert operations for VMs marked with
`testing.snapshot: true`; instructors do not create ad-hoc per-workload
snapshots. Prepare each participant range as follows:

1. create a new range from the immutable release blueprint;
2. run the complete, unfiltered deployment and require range state `SUCCESS`;
3. run `scripts/verify-range-baseline.py --range <range-id> --profile complete --deep --jump-host <user@host> --jump-identity <ssh-key>` and require every check to pass;
4. verify testing mode is disabled and no experiment run, Caldera operation, or router capture has been started;
5. run `ludus -r <range-id> testing start`; Ludus snapshots all configured testing VMs and applies the testing egress policy;
6. run the participant experiment only after snapshot creation;
7. export any instructor-required result, then run `ludus -r <range-id> testing stop`; Ludus reverts the testing VMs and restores normal egress;
8. rerun the complete deep baseline verifier before reassignment.

The router also boots from a clean versioned template, but Ludus manages it
outside the workload testing snapshot set. The administrator reset workflow must
stop capture, clear router-local PCAP, Zeek, and Vector spool state after evidence
has reached `clickhouse-ir`, and validate all four VMs before reassignment.

## Development install

Development also uses GitHub, never an upload-backed Source. Commit and push the
reviewed tree before refreshing the non-production Source:

```bash
ludus source add \
  https://github.com/Mastermjr/viberange-workshop.git \
  --id viberange-dev \
  --ref main \
  --all \
  --global

# After a reviewed commit is pushed:
ludus source sync viberange-dev
ludus source add viberange-dev --all --global --force
```

Tracking `main` is limited to disposable development validation. Participant
ranges use the release Source pinned to an immutable tag.

## Release install

Install an immutable release tag rather than the mutable development branch. Ludus 2.3.2 passes the ref to `git clone --branch`, so a raw commit ID is not accepted:

```bash
ludus source add <credential-free-repository-url> \
  --id viberange \
  --ref <immutable-release-tag> \
  --blueprints viberange \
  --templates viberange-router-debian12-v1-template,viberange-clickhouse-ir-debian12-v1-template,viberange-kali-caldera-v1-template,viberange-k3s-vuln-debian12-v1-template \
  --source-roles VibeRange.ludus_viberange_foundation,VibeRange.ludus_clickhouse_ir,VibeRange.ludus_vector_defender,VibeRange.ludus_vector_attacker,VibeRange.ludus_vector_victim,VibeRange.ludus_vector_router,VibeRange.ludus_router_evidence,VibeRange.ludus_run_control,VibeRange.ludus_ch_ui,VibeRange.ludus_jupyter,VibeRange.ludus_experiment_cli,VibeRange.ludus_detection_runner,cisagov.ludus_caldera_server,VibeRange.ludus_caldera_content,cisagov.ludus_caldera_agent,VibeRange.ludus_k3s_goat

ludus templates build -n viberange-router-debian12-v1-template
ludus templates build -n viberange-clickhouse-ir-debian12-v1-template
ludus templates build -n viberange-kali-caldera-v1-template
ludus templates build -n viberange-k3s-vuln-debian12-v1-template
ludus blueprint info viberange/viberange
```

The public Source requires no Git credential. Private forks must keep any repository credential outside the blueprint and participant ranges.

See:

- [`../../docs/ludus-host-prerequisites.md`](../../docs/ludus-host-prerequisites.md)
- [`../../docs/administration.md`](../../docs/administration.md)
- [`../../docs/participant-deployment-modes.md`](../../docs/participant-deployment-modes.md)
