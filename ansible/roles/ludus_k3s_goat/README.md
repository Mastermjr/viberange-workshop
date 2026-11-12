# ludus_k3s_goat

Ludus role for the victim side of the authorized purple-team range. It installs
k3s, Kubernetes API auditing, standalone Tetragon runtime observability,
Kubernetes Goat, and the persistent Goat access service.

Attach it to `k3s-vuln` before the victim Vector role:

```yaml
roles:
  - VibeRange.ludus_k3s_goat
  - VibeRange.ludus_vector_victim
```

## Evidence contract

Kubernetes audit and Tetragon answer different questions:

- API audit proves the authenticated user, verb, object, decision, and status;
- Tetragon proves node, pod, container, process lineage, and selected kernel
  activity.

The audit policy records scenario-relevant workload requests, RBAC activity,
and metadata for all remaining API calls. Secret bodies are never recorded.
Tetragon exports rotating JSON to `/var/run/cilium/tetragon/tetragon.log`; the
victim Vector role transports both streams with acknowledgements and disk
buffering.

## Tetragon design

The role pins Tetragon Helm chart and images to `1.8.0`, enables Kubernetes and
k3s containerd/CRI enrichment, records process credentials and namespaces, and
installs a namespaced `tcp_connect` TracingPolicy for `default` and the isolated
`viberange-validation` namespace. Default process lifecycle events require no
additional policy.

Tetragon runs standalone with k3s' existing Flannel CNI. Cilium and Hubble are
not installed: router PCAP/Zeek already provides replayable network evidence,
and replacing the CNI would add risk without improving the first workshop's
evidence contract.

After rollout, the role starts one ephemeral BusyBox pod and requires the
Tetragon JSON export to advance within 120 seconds. The pod is deleted and no
persistent synthetic canary remains. This catches the failure mode in which the
DaemonSet stays `Running` while CRI resolution warnings accompany a stale export.

## Prebuilt victim template

The canonical blueprint uses `viberange-k3s-vuln-debian12-v1-template`. The
image contains pinned k3s `v1.37.1+k3s1`, Helm `v3.19.0`, Vector `0.58.0`,
Kubernetes Goat `v2.3.0`, the Tetragon `1.8.0` chart, k3s air-gap images, and
build-time digest-resolved workload images. It deliberately never starts k3s
while building, so no cluster token, CA, node identity, range address, audit
log, Vector destination, or experiment data is cloned.

At deployment time this role validates `/etc/viberange-victim-template.json`,
writes range-specific audit and k3s configuration, starts a fresh single-node
cluster, installs the staged chart, and applies Goat and tracing-policy
manifests. It also sets deployed workload pod templates to
`imagePullPolicy: IfNotPresent`: Kubernetes otherwise treats Goat's `latest`
tags as `Always` and attempts registry resolution after an offline disk-snapshot
cold boot even though the exact images are already in k3s containerd. Standard
Debian templates remain a supported development fallback, but production resets
should use the prebuilt image.

## Operational behavior

The role is idempotent for packages, k3s configuration, pinned Helm deployment,
policy manifests, Goat checkout, and scenario deployment. It waits for node and
Tetragon readiness and verifies that the JSON export exists before completing.

The persistent access wrapper gates on the Kubernetes API, node readiness,
kubelet streaming health, and each selected Goat pod. Its seven `kubectl
port-forward` processes are supervised independently, so an application that is
still opening its target socket cannot tear down the other six participant
ports or impose a full-service restart delay.
