# VibeRange k3s victim Debian 12 v1 template

This Source-owned Ludus/Packer template moves stable victim dependencies out of
every participant deployment and into a host-built image:

- k3s `v1.37.1+k3s1` plus its pinned air-gap image archive;
- Helm `v3.19.0`;
- Vector `0.58.0`;
- Kubernetes Goat `v2.3.0` at commit
  `aa72b6173320ebe23fe7b5395d026dae3336e399`;
- the Tetragon Helm chart `1.8.0`;
- Kubernetes Goat and Tetragon images resolved to immutable digests at build
  time and stored as k3s-importable archives.

The image does **not** initialize k3s. It contains no cluster token, Kubernetes
CA, node identity, range address, audit record, Tetragon event, Vector
checkpoint/destination, participant credential, or experiment state. The Source
role validates the template marker, writes range-specific configuration, starts
a fresh cluster, imports the staged images, and applies the workloads.

Mutable upstream workload tags are unavoidable in Kubernetes Goat `v2.3.0`.
The build resolves each tag once, pulls by digest, records the effective digest
in `/etc/viberange/staged-images.txt`, and ships that archive. Rebuilding the
same template source can therefore capture newer upstream image content; treat
the built Proxmox template and the Source release as one promoted artifact and
retain the digest inventory with validation evidence.

## Build

```bash
ludus templates add -d templates/viberange-k3s-vuln-debian12-v1 --force
ludus templates build -n viberange-k3s-vuln-debian12-v1-template
```

Build this template once per Ludus host/release, before participant ranges are
created. Build it serially, not concurrently with another new range or template
build.

## Validation contract

A clean clone must prove:

1. `/etc/machine-id` and SSH host keys become unique on first boot;
2. `/etc/viberange-victim-template.json` matches the Source role pins;
3. k3s creates a fresh token, CA, kubeconfig, and node identity;
4. the node, Tetragon DaemonSet/operator, and Goat workloads become ready while
   internet access is blocked after deployment;
5. victim Vector starts only after its range-specific destination is written;
6. Kubernetes audit, Tetragon, and CRI evidence advances through Vector;
7. testing-mode snapshot stop/start returns the VM to the clean baseline;
8. deployment/reset duration and thin-provisioned storage are recorded.
