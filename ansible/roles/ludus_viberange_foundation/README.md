# ludus_viberange_foundation

Minimal idempotent role used as the explicit Stage 1 selection for progressive VibeRange deployments. It validates that Ludus provisioned a Linux endpoint with range networking, enables system time synchronization, waits for an NTP-synchronized clock, and writes a non-secret foundation marker. Synchronized source clocks are a required forensic control for bounded experiment reconstruction.

The complete blueprint attaches this role to all three workload VMs. Progressive deployment begins with:

```bash
ludus range deploy --only-roles VibeRange.ludus_viberange_foundation
```

A plain `ludus range deploy` runs this role together with the complete dependency graph.
