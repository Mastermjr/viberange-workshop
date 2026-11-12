# Security policy

VibeRange intentionally deploys vulnerable workloads and offensive automation for authorized, isolated training environments.

## Safe deployment

- Never expose participant ranges, Kubernetes Goat, Caldera, CH-UI, Jupyter, Ludus, or Proxmox directly to the public internet.
- Render production range configurations with the target site's protected management, storage, out-of-band, and routed-network CIDRs.
- Keep Ludus, Proxmox, API, SSH, repository, and application credentials outside this repository.
- Give participants only their assigned WireGuard profile and approved range-local credentials.
- Validate assigned-service access, cross-range denial, management-plane denial, revocation, router cleanup, and snapshot reset before reuse.
- Treat generated evidence as potentially sensitive and apply an explicit retention policy.

See [`docs/participant-isolation.md`](docs/participant-isolation.md) and [`docs/administration.md`](docs/administration.md).

## Reporting a vulnerability

Use GitHub's private vulnerability-reporting or security-advisory feature for the repository. Do not include live credentials, private keys, participant evidence, management addresses, or exploit data from systems you do not own or have authorization to test.
