# VibeRange router Debian 12 v1 template

This self-contained Ludus/Packer template starts from the same Debian 12.1
installer and preseed contract as Ludus server `2.3.2`, then bakes only generic,
non-secret router evidence prerequisites:

- Zeek `9.0.1-0` from the checksum- and fingerprint-verified official OBS repository;
- Vector `0.58.0` from a checksum-pinned Debian package;
- `tcpdump`, `systemd-timesyncd`, Python, and basic package/locking tools;
- empty root-owned evidence and Vector directories;
- first-boot SSH host-key regeneration.

It deliberately does **not** contain a range ID, IP address, Vector destination,
capture interface, run state, PCAP, credential, or active service configuration.
The thin Source roles still discover the per-range interface, write Vector and
capture configuration, install controller scripts, validate versions and NTP,
and start services.

## Build

```bash
ludus templates add -d templates/viberange-router-debian12-v1 --force
ludus templates build -n viberange-router-debian12-v1-template
```

The canonical Source installs this directory as a Source-owned template. Build
it once per Ludus host/release before creating participant ranges.

## Provenance

The Packer builder and preseed are adapted from Bad Sector Labs Ludus `2.3.2`
tag `bba3dd3ab315b12084c6c107a1683fe013c6977e`. The Debian icon comes from the
Bad Sector Labs Source template catalog. VibeRange owns the additional generic
provisioning playbook and supply-chain pins.
