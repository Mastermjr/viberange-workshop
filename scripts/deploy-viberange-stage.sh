#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${VIBERANGE_STAGE_MANIFEST:-$ROOT/config/viberange-stages.json}"
LUDUS_CMD="${LUDUS_CMD:-ludus}"
read -r -a ludus_command <<<"$LUDUS_CMD"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: deploy-viberange-stage.sh [--dry-run] <range-id> <1-6|complete>

Deploy one cumulative progressive stage or the complete blueprint role graph.
The range must already be instructor-created and configured from VibeRange.
Only user1-user5 and viberange-validation are accepted by default.
EOF
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi
[[ $# -eq 2 ]] || { usage >&2; exit 2; }
range_id=$1
stage=$2

if [[ ! "$range_id" =~ ^(user[1-5]|viberange-validation)$ ]]; then
  printf 'ERROR: refusing unapproved range ID: %s\n' "$range_id" >&2
  exit 2
fi
[[ -f "$MANIFEST" ]] || { printf 'ERROR: missing stage manifest: %s\n' "$MANIFEST" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo 'ERROR: jq is required' >&2; exit 2; }

if [[ "$stage" == "complete" ]]; then
  label=complete
  command=("${ludus_command[@]}" -r "$range_id" range deploy)
else
  jq -e --arg stage "$stage" '.stages[$stage]' "$MANIFEST" >/dev/null || {
    printf 'ERROR: unknown stage %s\n' "$stage" >&2
    exit 2
  }
  label=$(jq -r --arg stage "$stage" '.stages[$stage].name' "$MANIFEST")
  roles=$(jq -r --arg stage "$stage" '.stages[$stage].roles | join(",")' "$MANIFEST")
  command=("${ludus_command[@]}" -r "$range_id" range deploy --only-roles "$roles")
fi

printf 'range=%s profile=%s\n' "$range_id" "$label"
printf 'command:'
printf ' %q' "${command[@]}"
printf '\n'

if "$DRY_RUN"; then
  exit 0
fi

"${command[@]}"
