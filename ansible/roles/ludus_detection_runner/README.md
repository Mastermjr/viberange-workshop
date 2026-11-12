# ludus_detection_runner

Deploys the workshop SQL rules, webhook receiver, and a small scheduled
ClickHouse runner. Detection matches are deduplicated and written back to
`ir.detections`, preserving queryable experiment evidence without requiring an
external alerting service.

The role installs:

- scheduled YAML rules in `/opt/viberange-detection/rules`;
- equivalent run-parameterized participant SQL in
  `/opt/viberange-detection/queries`;
- the runner and receiver services;
- stable evidence fingerprinting that sorts result rows before hashing.

The scenario-grounded set detects Kubernetes Secret enumeration from audit logs, service-account token reads from Tetragon, and chroot execution into the mounted host filesystem from Tetragon. Participant queries and interpretation guidance live in [`../../../09-detection-and-reporting/`](../../../09-detection-and-reporting/).
