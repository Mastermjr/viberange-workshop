# VibeRange Ansible roles

The Git-backed Ludus Source installs these roles with the blueprint. Operators should install an immutable Source release with `--all --global`; participants do not publish, edit, or invoke roles directly.

## Licensing

The retained `cisagov.ludus_caldera_server` and `cisagov.ludus_caldera_agent` role code is distributed under GPL-3.0-only; the full text is in [`LICENSE`](LICENSE). VibeRange-authored roles remain under the repository's root BSD-3-Clause license. Individual role metadata and attribution remain authoritative for upstream-derived code.

## Role groups

### Range foundation and analysis

- `ludus_viberange_foundation` validates the base Linux guests and synchronized clocks.
- `ludus_clickhouse_ir` configures ClickHouse on the analysis VM.
- `ludus_ch_ui` provides the read-only participant analytics interface.
- `ludus_jupyter` provides the no-login participant terminal and reconstruction notebook.
- `ludus_run_control`, `ludus_experiment_cli`, and `ludus_detection_runner` implement the bounded experiment lifecycle and analysis workflow.

### Evidence transport and router capture

- `ludus_vector_attacker`, `ludus_vector_victim`, and `ludus_vector_router` collect source-native records.
- `ludus_vector_defender` is the stable role identifier for the central Vector aggregator.
- `ludus_router_evidence` controls bounded PCAP capture, sealing, offline Zeek processing, and manifest delivery.

### Prepared attacker and victim

- `ludus_caldera_server` and `ludus_caldera_agent` retain their installed `cisagov` role namespace for compatibility with the canonical range configuration.
- `ludus_caldera_content` installs the versioned VibeRange abilities, fact source, adversary, and payload wrapper.
- `ludus_k3s_goat` initializes the prepared victim, Kubernetes Goat, Kubernetes audit, Tetragon, and victim telemetry.

## Deployment contract

The authoritative role ordering and dependencies are in:

```text
blueprints/viberange/range-config.yml
```

Range-specific addresses, credentials, run identity, and mutable evidence are created during deployment. They are never baked into templates or committed to the repository.

To update deployed role code, publish a new immutable Source version, synchronize/install that Source in Ludus, and deploy the affected role set on a disposable range before production rollout.
