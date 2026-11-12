# VibeRange administration

This runbook records the instructor and platform-administrator workflow for maintaining the public Git-backed Ludus Source, publishing blueprint releases, promoting them into Ludus, and applying them to ranges.

Participant accounts must never receive Source-management access or repository credentials.

## Public release Source

The release registration is:

| Setting | Value |
|---|---|
| Source ID | `viberange` |
| Source type | Git |
| Repository URL | `https://github.com/Mastermjr/viberange-workshop.git` |
| Release ref | `v0.11.14` |
| Blueprint | `viberange/viberange` |
| Blueprint version | `0.11.14` |
| Source-role scope | Global |

The URL is intentionally credential-free. No deploy key or repository token is required for the public Source.

## Security rules

- Never place credentials in Git, issue trackers, chat, logs, range files, participant handoffs, or command-line arguments.
- If maintaining a private fork, use a repository-scoped read-only credential stored only in protected host configuration.
- Register VibeRange only as a Git Source cloned from GitHub; do not use directory, tar, or upload-backed Sources.
- Pin production Sources to immutable release tags. Only the disposable `viberange-dev` validation Source may track `main`.
- Never move or replace an existing release tag. Publish a new version instead.
- Validate a release on a non-production participant range before applying it to active ranges.

## Optional private-fork setup

Public installations should skip this section and use the credential-free HTTPS URL directly. These steps apply only to operators maintaining a private fork.

### 1. Add the public deploy key in GitHub

In the repository settings, add the public half of the dedicated key as a deploy key with write access disabled.

Keep the private half in a protected staging location only long enough to install it. The commands below use `/secure/staging/viberange_source_deploy` as a placeholder; do not copy that literal path.

### 2. Install the private key as root

Run as root on the Ludus host.

```bash
key=/secure/staging/viberange_source_deploy
group=$(id -gn ludus)

install -d -m 0700 -o ludus -g "$group" /home/ludus/.ssh
install -m 0600 -o ludus -g "$group" \
  "$key" /home/ludus/.ssh/viberange_source_deploy
```

Create `/home/ludus/.ssh/config`:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/viberange_source_deploy
    IdentitiesOnly yes
```

Then enforce ownership and permissions:

```bash
chown ludus:"$group" /home/ludus/.ssh/config
chmod 0600 /home/ludus/.ssh/config
```

Delete the temporary staged copy after installation.

### 3. Install authenticated GitHub host keys

Run as `ludus`. This obtains GitHub's published SSH keys through its HTTPS API instead of blindly accepting the first SSH connection:

```bash
su - ludus

curl -fsSL https://api.github.com/meta \
  | jq -er '.ssh_keys[] | "github.com " + .' \
  > ~/.ssh/known_hosts

chmod 0600 ~/.ssh/known_hosts
ssh-keygen -F github.com -f ~/.ssh/known_hosts >/dev/null
```

### 4. Configure the private-fork URL bridge

Ludus 2.3.2 accepts the HTTPS repository URL as a Source URL, but the tested client/server path did not classify `ssh://` as a valid Source URL. Configure Git for the OS `ludus` account to rewrite GitHub HTTPS clone requests to SSH:

```bash
git config --global \
  url."git@github.com:".insteadOf \
  "https://github.com/"
```

This keeps the URL stored in Ludus credential-free while the Git subprocess uses the read-only deploy key.

### 5. Verify access as `ludus`

```bash
ssh -T -o BatchMode=yes git@github.com
```

GitHub returns exit status `1` because it does not provide shell access, but the output must contain:

```text
You've successfully authenticated
```

Verify repository reads:

```bash
git ls-remote \
  https://github.com/Mastermjr/viberange-workshop.git \
  refs/heads/main
```

Do not continue if either test requests interactive credentials.

## Publishing a blueprint release

The blueprint version in `blueprints/viberange/blueprint.yml` and the Git tag should agree.

Example release:

```bash
version=0.11.14
tag="v${version}"

# Run repository validation first.
git status --short
git diff --check

# Commit and push the reviewed Source changes.
git push origin main

# Create a new immutable annotated release tag.
git tag -a "$tag" -m "VibeRange blueprint ${tag}"
git push origin "$tag"
```

Confirm the tag resolves to the intended commit:

```bash
git rev-list -n 1 "$tag"
git ls-remote origin "refs/tags/${tag}^{}"
```

On the tested Ludus 2.3.2 server, passing a raw commit hash to `--ref` failed because the server used `git clone --branch`. Use a published immutable tag rather than a raw commit hash.

## Initial Source registration

Run as a Ludus administrator after the tag is visible from the host:

```bash
ludus source add \
  https://github.com/Mastermjr/viberange-workshop.git \
  --id viberange \
  --ref v0.11.14 \
  --all \
  --global \
  --force
```

This registers the Git Source, installs `viberange/viberange`, and installs the Source roles globally for prepared participant ranges.

For disposable pre-release validation, register a second **Git-backed** Source;
do not upload a local archive:

```bash
ludus source add \
  https://github.com/Mastermjr/viberange-workshop.git \
  --id viberange-dev \
  --ref main \
  --all \
  --global \
  --force
```

After each reviewed push, refresh it with `ludus source sync viberange-dev`
followed by `ludus source add viberange-dev --all --global --force`.

Verify registration:

```bash
ludus source list --json \
  | jq '.[] | select(.sourceID == "viberange")'

ludus source list viberange --catalog --json
ludus blueprint list --json \
  | jq '.[] | select(.blueprintID == "viberange/viberange")'
```

Reject any upload-backed VibeRange registration:

```bash
ludus source list --json | jq -e '
  [ .[] | select(.sourceID | startswith("viberange")) | .type ]
  | length > 0 and all(. == "git")'
```

Required values include:

- every VibeRange Source has type `git`;
- expected HTTPS URL;
- expected release tag in `ref`;
- `lastSyncStatus` equal to `ok`;
- expected blueprint version;
- required local roles installed globally.

## Promoting a later Git release

Git pushes do **not** silently update the installed workshop Source. This is intentional. Promote an approved release explicitly:

```bash
tag=v0.11.14

ludus source set-url viberange --ref "$tag"
ludus source sync viberange
ludus source add viberange --all --global --force
```

The commands have distinct purposes:

1. `source set-url --ref` selects the new release tag.
2. `source sync` fetches it and refreshes the Source catalog; sync alone does not install changes.
3. `source add viberange --all --global --force` installs the refreshed blueprint and roles.

This sequence can be placed in instructor automation that calls the Ludus API through the CLI. Keep administrator API credentials outside scripts and Git.

## Applying a release to ranges

Updating the Source does not silently mutate existing ranges. The generic
Source cannot contain site management CIDRs, so do not apply it directly to a
production participant range. Export/get the installed canonical configuration
into protected operator state if needed, then render the repository-matching
configuration with the protected site list:

```bash
range="${RANGE_ID:?set RANGE_ID to the participant slot}"
protected=/protected/viberange
range_number=$(ludus -u "$range" range list --json | jq -er '.rangeNumber')
wireguard_client_octet=$(ludus users list all --json \
  | jq -er --arg user "$range" '.[] | select(.userID == $user) | .userNumber')

scripts/render-secure-range-config.sh \
  --range-number "$range_number" \
  --blocked-networks "$protected/blocked-networks.json" \
  --wireguard-client-octet "$wireguard_client_octet" \
  --output "$protected/${range}-range-config.yml"

ludus -r "$range" range config set \
  -f "$protected/${range}-range-config.yml"
ludus -r "$range" range deploy
```

The JSON file must contain a non-empty `always_blocked_networks` array with the
exact Proxmox and site management, storage, out-of-band, tailnet-routed, and Tailscale
gateway CIDRs. The renderer rejects any entry overlapping the assigned
`10.<range-number>.0.0/16` and writes the rendered YAML mode `0600`. Keep both
input and output outside Git and participant-visible storage.

For a disposable non-production validation with no site details, direct
`ludus blueprint apply` remains available, but it does not satisfy the
participant isolation gate.

Operational rules:

- serialize new range clone/base-provisioning operations;
- do not apply a new release to a range in testing mode without an intentional override;
- preserve deployment errors before retrying;
- inspect for partial VMs before destructive cleanup;
- test a new release on an inactive validation range before participant rollout;
- do not destroy an active participant range merely to update roles.

For an intentionally clean validation, destroy only the selected validation range's VMs, reapply the blueprint, and deploy it from empty state:

```bash
range=viberange-validation

ludus -r "$range" range rm --no-prompt
ludus blueprint apply viberange/viberange --target-range "$range"
ludus -r "$range" range deploy
```

`range rm` is destructive and must not be used against the active test or participant range without explicit approval.

## Release verification checklist

After promotion, record sanitized evidence for:

- Source ID, URL, release tag, sync status, and blueprint version;
- all expected roles installed;
- clean deployment reaches `SUCCESS`;
- all expected VMs are powered and reachable;
- ClickHouse, Vector, Caldera, k3s, Kubernetes Goat, detections, and UI services are healthy;
- telemetry is being ingested;
- intended inter-VLAN paths are allowed and WireGuard/guest paths to host management, other ranges, storage, OOB and tailnet-routed destinations are denied;
- testing/reset behavior works;
- the validation range is powered off or removed afterward to restore host capacity.

Never include API keys, passwords, private keys, or credential-bearing command output in validation reports.

## Troubleshooting

### `Remote branch <commit> not found`

The tested server attempted `git clone --branch <ref>`, which does not clone an arbitrary commit hash. Publish and select an immutable annotated tag.

### Source sync succeeds but roles or blueprint do not change

`ludus source sync` refreshes the catalog only. Re-run:

```bash
ludus source add viberange --all --global --force
```

### Installed Source changes do not appear in an existing range

Reapply `viberange/viberange` to that range, then run the appropriate deployment action. Source promotion alone does not rewrite an existing range.

### Git works in an administrator shell but Source cloning fails

Test as the OS `ludus` account. The Ludus service performs Source Git operations in that account's environment, not the SSH operator's account.

Check:

```bash
su - ludus
id
stat -c '%a %U:%G %n' ~/.ssh ~/.ssh/*
git config --global --get-regexp '^url\.'
git ls-remote \
  https://github.com/Mastermjr/viberange-workshop.git HEAD
```

Do not print or inspect private-key contents while troubleshooting.
