# Real-world context for `k8s-goat-attack`

The workshop attack chain is deliberately compressed for a two-hour lab. Its exact sequence—an exposed GoTTY terminal leading through a privileged Kubernetes Goat workload, a host-root mount, node control, and a cluster-admin proof—is a **composite scenario**, not a claim that one published incident followed every identical step.

The individual techniques are realistic and documented in incident-response and threat-hunting literature:

- **TeamPCP:** Elastic documents attackers using an overprivileged Kubernetes identity to create a privileged DaemonSet with `hostPath`, `hostPID`, and `hostNetwork`, enabling node-level access. This is the closest analogue to the workshop's privileged-container and host-mount stages.
  <https://www.elastic.co/security-labs/blog/teampcp-container-attack-scenario>
- **AKS threat hunting:** Microsoft provides hunting guidance for privileged pods, `hostPID`, and sensitive host mounts such as `/`, `/etc`, `/proc`, and container-runtime sockets.
  <https://www.microsoft.com/en-us/msrc/blog/2023/03/azure-kubernetes-service-aks-threat-hunting/>
- **RBAC Buster:** Aqua reports attackers abusing exposed Kubernetes APIs and excessive RBAC to create persistent privileged identities and malicious DaemonSets across multiple clusters.
  <https://www.aquasec.com/blog/leveraging-kubernetes-rbac-to-backdoor-clusters/>

Kubernetes Goat makes the initial foothold intentionally convenient by exposing a browser terminal. GoTTY itself is not the central lesson. The important failure combination is:

1. remotely reachable administrative/debug functionality;
2. a privileged workload;
3. `hostPID` or comparable host namespace access;
4. the host root mounted into the container;
5. node Kubernetes credentials reachable after host access;
6. insufficient prevention, audit, or runtime controls.

The workshop should describe `k8s-goat-attack` as a reproducible emulation assembled from documented real techniques. It should cite the reports above for realism while avoiding the claim that they describe the exact same end-to-end chain.
