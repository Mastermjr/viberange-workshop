# 06 — Kubernetes Goat prepared victim

`k3s-vuln` hosts the intentionally vulnerable Kubernetes Goat target. The instructor deploys it through the canonical VibeRange blueprint; participants do not clone the repository, install k3s, pull images, or modify audit policy during the workshop.

## Authorized target

```text
hostname: k3s-vuln
address:  10.<range-number>.30.30
ports:    1230–1236
```

The prepared Kali/Caldera workflow targets only the assigned range. These services are intentionally vulnerable training systems; their presence is not authorization to test anything outside the range.

From `kali-caldera`, the range-local entry points are:

```text
http://10.<range-number>.30.30:1230/
http://10.<range-number>.30.30:1231/
http://10.<range-number>.30.30:1232/
http://10.<range-number>.30.30:1233/
http://10.<range-number>.30.30:1234/
http://10.<range-number>.30.30:1235/
http://10.<range-number>.30.30:1236/
```

The prepared scenario and exact port progression are versioned with the checked-in Caldera content. Do not substitute an unrelated Goat walkthrough and then treat its evidence as the workshop's validated run.

## Participant purpose

Participants should understand:

1. which vulnerable path the prepared operation exercises;
2. which actions are intended attacker ground truth;
3. which victim-side effects are expected;
4. which independent sources should observe each phase;
5. which transitions are prerequisites or instructor-controlled handoffs rather than causal exploit steps.

Kubernetes Goat is a collection of mostly independent labs. The workshop must not present a sequence as one causal kill chain unless that exact transition was validated on the pinned victim image.

## Evidence expectations

The attack is investigated using:

- Caldera operation and link results;
- Kali auditd;
- router PCAP and Zeek;
- Kubernetes API audit;
- Tetragon process and socket evidence;
- selected container logs;
- detections that cite the underlying source events.

See module 05 for telemetry semantics, module 07 for the prepared attacker operation, module 08 for run execution/investigation, and module 09 for detections and notebook output.

## Reset boundary

Participants do not manually rebuild the cluster between runs. Follow the documented experiment cleanup and instructor Ludus reset workflow. A reset must not be confused with ordinary run completion: the latter seals evidence, while the former returns VM state to an instructor-defined baseline.

## References

- [`../05-k8s-telemetry/README.md`](../05-k8s-telemetry/README.md)
- [`../07-caldera/README.md`](../07-caldera/README.md)
- [`../08-experiment-framework/README.md`](../08-experiment-framework/README.md)
- [`../docs/architecture.md`](../docs/architecture.md)
