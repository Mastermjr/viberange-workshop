# `ludus_jupyter`

Installs and runs the participant JupyterLab environment on `clickhouse-ir`.

The role owns runtime only:

- pinned Python requirements;
- `/opt/viberange/jupyter-venv`;
- password-locked `viberange-jupyter` systemd service with a real Bash shell;
- JupyterLab interactive terminals with passwordless sudo inside the disposable analysis VM;
- persistent notebooks/output under `/var/lib/viberange-jupyter`;
- the versioned deterministic run-reconstruction notebook, including the Caldera ability-to-evidence graph;
- unauthenticated Jupyter application access bounded by the assigned per-client WireGuard firewall rule;
- root-only participant URL handoff containing no credential;
- runtime/ClickHouse health validation.

When the Source-owned analysis template reports a baked wheelhouse, installation uses `--no-index`. A standard-template fallback can download the same pinned requirements for development, but publication acceptance requires the prebuilt path.

The role seeds a runtime check alongside the versioned reconstruction notebook; the base image itself makes no scenario-specific validation claims.

Default URL:

```text
http://10.<range-number>.10.10:8889/lab
```

The instructor retrieves `/var/lib/viberange-jupyter/participant-login.txt` through the approved participant handoff. The URL contains no Jupyter token or password; workstation routing is provided by the assigned WireGuard profile.

Participants are intentionally trusted with root inside their assigned analysis
VM. This does not grant router, Proxmox, Ludus, management-plane, or cross-range
access; those remain separate network/control-plane boundaries.
