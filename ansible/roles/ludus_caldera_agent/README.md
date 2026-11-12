# `ludus_caldera_agent`

Installs the MITRE Caldera Sandcat agent used by the prepared VibeRange operation. In the canonical blueprint the role runs on `kali-caldera`, installs the Linux agent under `/opt/caldera-agent`, and manages it with systemd.

## VibeRange contract

- The agent connects only to the range-local Caldera server on TCP/8888.
- The canonical group is the prepared red-side group defined by role variables.
- The Kali service user and path are configured explicitly by the blueprint.
- The participant experiment CLI verifies the prepared agent before starting an operation.
- Participants do not receive an arbitrary agent installer, Caldera API key, or agent-management shell.
- Workload persistence outside the disposable attacker VM is not part of the workshop.

## Important variables

| Variable | Default | Purpose |
|---|---|---|
| `ludus_caldera_agent_server_ip` | `""` | Range-local Caldera address |
| `ludus_caldera_agent_server_port` | `8888` | Caldera HTTP port |
| `ludus_caldera_agent_group` | `"red"` | Prepared agent group |
| `ludus_caldera_agent_linux_path` | `/opt/caldera-agent/sandcat` | Linux agent path |
| `ludus_caldera_agent_linux_user` | `ansible_user` | Linux service account |
| `ludus_caldera_agent_linux_service` | `caldera-agent` | systemd unit name |

The role must run after `ludus_caldera_server`; canonical ordering is defined in `blueprints/viberange/range-config.yml`.

## License and attribution

GPL-3.0-only; see [`../../LICENSE`](../../LICENSE). Upstream role namespace and attribution remain `cisagov`.
