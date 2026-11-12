# `ludus_caldera_content`

Installs and enables the workshop-owned `viberange` plugin in the pinned
Caldera server. The plugin contains stable, version-controlled Kubernetes Goat
abilities, one atomic adversary, and a range-specific fact source.

## Installed content

| Object | Stable ID |
|---|---|
| Adversary | `c0a1de4a-701d-4c9a-b541-936ff3871205` |
| Fact source | `c0a1de4a-701d-4c9a-b541-936ff3871300` |

The `k8s-goat-attack` scenario is one seven-link atomic adversary. It performs
authorized service discovery, bounded GoTTY access to the privileged
system-monitor workload, container-root proof, a credential-safe repeated
service-account authorization probe, host-mount escape proof, bounded host
identity proof, and a non-destructive cluster-admin namespace query. Secret
response bodies are never retained.

## Facts

The role renders target IP and port facts from the Ludus range number. The run
ID deliberately defaults to `VIBERANGE_RUN_ID_REQUIRED`; the experiment driver
must replace it before launching an operation. Commands consume facts rather
than embedding a particular range address.

## Idempotency

The role copies deterministic plugin content, adds the plugin name to Caldera's
configuration once, restarts only after a content/configuration change, waits
for service readiness, and verifies the stable IDs through the local API.
