# `ludus_router_evidence`

Installs the Community-compatible VibeRange router evidence path. The role runs
on the analysis VM and delegates capture tooling to the Ludus-managed router;
it does not require Pro/Enterprise router-role attachment.

## Evidence lifecycle

```text
start RUN_ID
→ capture victim-facing traffic into one bounded PCAP
→ stop RUN_ID
→ stop and seal the PCAP
→ calculate SHA-256, size, packet count, and timestamps
→ replay the sealed PCAP through pinned Zeek
→ enrich each Zeek JSON row with run/artifact identity
→ append Zeek rows and the artifact manifest to router Vector spools
→ project the manifest into ir.pcap_artifacts
```

Only one capture may run per router. The systemd unit limits each capture to one
hour and 4 GiB by default, and the controller refuses to begin below its minimum
free-space threshold.

## Operator interface

On the router:

```bash
sudo viberange-router-evidence start RUN_ID
sudo viberange-router-evidence status
sudo viberange-router-evidence stop RUN_ID
sudo viberange-router-evidence replay RUN_ID REPLAY_ID
```

Run and replay IDs are restricted to ASCII letters, digits, underscores, and
hyphens. Artifacts are root-only under
`/var/lib/viberange-router-evidence/runs/`.

## Testing-mode reset behavior

The versioned router template contains no captures or experiment identity.
Ludus testing mode reverts the configured workload snapshots; the ADMIN-owned
range reset workflow handles the managed router by stopping any active capture,
allowing the sealed manifest and Zeek rows to reach `clickhouse-ir`, and then
removing router-local run directories and transient Vector/Zeek spool state.
No participant PCAP is retained on the router for reuse by the next participant.

The `replay` command remains an instructor troubleshooting tool for a sealed
artifact before ADMIN cleanup. It is not part of normal participant reset or
long-term evidence retention.

## Retention

`clickhouse-ir` is the exercise evidence destination. Router-local PCAP and
Zeek files are bounded working data: capture is limited to one hour and 4 GiB,
and administrator cleanup may discard it after successful sealing/forwarding and any required instructor export. Reset automation must verify the router returns to idle before reassignment.

## Capture placement

The role discovers the router interface selected by the route to the assigned victim VM. Capturing on that victim-facing path observes authorized attacker-to-victim traffic once and avoids duplicate packets from capturing on every router interface.

## Supply-chain pins

Zeek comes from the official Zeek OBS Debian 12 repository. The role pins the
package version, repository-key SHA-256, and signing-key fingerprint before
installing. The pinned release is Zeek `9.0.1`.
