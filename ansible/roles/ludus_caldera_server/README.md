# `ludus_caldera_server`

Deploys pinned [MITRE Caldera](https://github.com/mitre/caldera) on the `kali-caldera` attacker VM. The role installs or verifies the required Go, Node, and Python toolchains, clones Caldera recursively, builds the Magma frontend, and runs Caldera as a systemd service on TCP/8888.

The Source-owned Kali template declares `caldera_system_prerequisites: true` in `/etc/viberange-kali-caldera-template.json`. The role validates that contract and reuses the baked system dependencies. A fallback install path remains available for disposable development images.

The frontend build completes before systemd starts. A marker keyed by Caldera version and `package-lock.json` checksum allows idempotent reruns; missing output or a broken runtime forces a clean rebuild.

## VibeRange contract

- Caldera version is pinned by `ludus_caldera_server_version`.
- The service binds TCP/8888 inside the assigned range.
- The range firewall exposes the UI only to that participant's WireGuard client.
- API keys and application credentials are extracted with Ansible logging suppressed.
- Downstream content, agent, and experiment roles consume facts without writing credentials to the repository.
- Participants inspect the prepared operation but do not administer the server or receive its API key.

## Important variables

| Variable | Default | Purpose |
|---|---|---|
| `ludus_caldera_server_version` | `"5.3.0"` | Caldera git tag/branch |
| `ludus_caldera_server_python_version` | `"3.12"` | Managed Python runtime |
| `ludus_caldera_server_go_version` | `"1.23.3"` | Go toolchain |
| `ludus_caldera_server_node_version` | `"22"` | Node.js major version |
| `ludus_caldera_server_install_dir` | `/opt/caldera` | Installation directory |
| `ludus_caldera_server_port` | `8888` | HTTP service port |
| `ludus_caldera_server_sleep_min` | `2` | Minimum agent sleep |
| `ludus_caldera_server_sleep_max` | `5` | Maximum agent sleep |

Role ordering is defined in `blueprints/viberange/range-config.yml`.

## License and attribution

GPL-3.0-only; see [`../../LICENSE`](../../LICENSE). Upstream role namespace and attribution remain `cisagov`.
