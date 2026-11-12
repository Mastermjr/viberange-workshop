# `ludus_experiment_cli`

Installs the participant-facing bounded experiment command on `clickhouse-ir`.

```bash
sudo viberange experiment start SCENARIO [--scenario-version VERSION]
sudo viberange experiment status
sudo viberange experiment stop [--notes NOTE]
sudo viberange experiment abort --reason REASON
```

The role provisions a range-local Ed25519 key whose router authorization is forced to a validator that permits only:

```text
status
start RUN_ID
stop RUN_ID
```

No interactive router shell, agent forwarding, port forwarding, X11 forwarding, or PTY is permitted through this key. The participant may use sudo in the assigned VM; no Ludus administrator, Source, Proxmox, ClickHouse write, or Caldera API credential is exposed by the CLI.

Current orchestration:

- creates/starts the append-only run ledger;
- starts router capture with the same run ID;
- creates a run-specific Caldera fact source from the checked-in range facts;
- launches and polls the single `k8s-goat-attack` atomic adversary;
- requires exactly the seven expected status-0 links;
- exports operation/link ground truth with explicit run identity to the central Vector file spool;
- registers operation and adversary IDs in the run manifest;
- reports run/capture/attack status;
- stops/seals capture and completes the run;
- seals available evidence and records an aborted state on failure or abort.

The range-local Caldera URL and red API key are stored in the root-owned CLI
configuration. Participants already have sudo in their disposable range; the
key is not treated as a boundary inside that range, but it is kept out of Git,
logs, reports, and ClickHouse.
