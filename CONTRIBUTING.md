# Contributing

Contributions that improve portability, evidence integrity, detections, documentation, or workshop usability are welcome.

## Before submitting

1. Work from a branch based on `main`.
2. Keep credentials, participant evidence, private network details, and environment-specific state out of commits and issue text.
3. Update authoritative roles or blueprint content first; keep template-owned copies synchronized where required.
4. Run:

   ```bash
   nix develop
   ./scripts/workshop-preflight.sh
   git diff --check
   gitleaks detect --no-git --source . --config .gitleaks.toml --redact
   ```

5. For deployment changes, validate a clean disposable range and its reset path.
6. For security-boundary changes, include positive and negative tests without publishing private addresses or credentials.

Do not move an existing release tag. Release changes require a new immutable version and tag.
