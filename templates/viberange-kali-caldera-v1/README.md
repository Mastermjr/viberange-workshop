# `viberange-kali-caldera-v1-template`

Source-owned Kali attacker template derived from the canonical [Ludus Kali template](https://gitlab.com/badsectorlabs/ludus).

The image bakes only shared immutable prerequisites:

- Kali rolling core and XFCE desktop;
- KasmVNC as provided by the upstream Ludus Kali template;
- auditd and generic command-line prerequisites;
- Caldera's compiler, Python, XML/FFI, network, and package-management system prerequisites, so clean range deployment does not depend on a rolling Kali mirror transaction;
- Vector `0.58.0`, pinned by SHA-256 and disabled until first-boot configuration;
- first-boot SSH host-key regeneration.

It deliberately contains no range identity, Vector pipeline, Caldera server or
agent state, API key, operation, run ID, capture, or experiment evidence. Those
remain range-specific Ansible state. The build removes mutable Vector and
Caldera spool contents and records `/etc/viberange-kali-caldera-template.json`.

## Build

The template is cataloged by the VibeRange GitHub-backed Ludus Source:

```bash
ludus templates build -n viberange-kali-caldera-v1-template
ludus templates status
ludus templates logs
```

Build Source templates serially on the workshop host. Ludus injects Proxmox,
storage, ISO, and Ansible variables into Packer.

## Validation boundary

After the template build, create a clean range through the blueprint and verify:

- every attacker VM reports the template marker and pinned Vector version;
- Vector has no package-default configuration before the range role runs;
- Caldera and experiment state are absent from the image;
- the complete role graph initializes Caldera, its agent, the VibeRange plugin,
  and attacker telemetry successfully;
- a testing snapshot/reset returns the attacker to the clean configured state.
