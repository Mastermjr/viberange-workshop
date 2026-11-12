#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLUEPRINT="$ROOT/blueprints/viberange/range-config.yml"
base_config="$BLUEPRINT"
wireguard_client_octet=

usage() {
  cat <<'EOF'
Usage: render-secure-range-config.sh \
  [--base-config <current-range-config.yml>] \
  --range-number <1-254> \
  --blocked-networks <protected.json> \
  --wireguard-client-octet <2-254> \
  --output <protected-range-config.yml>

Render the canonical blueprint, or an explicitly supplied current live config,
with site-specific management networks in
network.always_blocked_networks. The JSON file must have this form:

  {"always_blocked_networks":["management CIDR", "storage CIDR"]}

Use real CIDRs only in protected operator state, never in the repository.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

range_number=
blocked_networks=
output=
while (($#)); do
  case "$1" in
    --base-config) [[ $# -ge 2 ]] || die 'missing --base-config value'; base_config=$2; shift 2 ;;
    --range-number) [[ $# -ge 2 ]] || die 'missing --range-number value'; range_number=$2; shift 2 ;;
    --blocked-networks) [[ $# -ge 2 ]] || die 'missing --blocked-networks value'; blocked_networks=$2; shift 2 ;;
    --wireguard-client-octet) [[ $# -ge 2 ]] || die 'missing --wireguard-client-octet value'; wireguard_client_octet=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die 'missing --output value'; output=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $range_number =~ ^[0-9]+$ ]] || die '--range-number must be an integer'
((range_number >= 1 && range_number <= 254)) || die '--range-number must be between 1 and 254'
[[ -r $base_config ]] || die "base configuration is not readable: $base_config"
[[ -r $blocked_networks ]] || die "blocked-network file is not readable: $blocked_networks"
[[ $wireguard_client_octet =~ ^[0-9]+$ ]] || die '--wireguard-client-octet must be an integer'
((wireguard_client_octet >= 2 && wireguard_client_octet <= 254)) || die '--wireguard-client-octet must be between 2 and 254'
[[ -n $output ]] || die '--output is required'
[[ $output != "$BLUEPRINT" && $output != "$base_config" ]] || die 'refusing to overwrite the base configuration'
command -v python3 >/dev/null 2>&1 || die 'python3 is required'
command -v yq >/dev/null 2>&1 || die 'yq v4 is required (available through nix develop)'

mkdir -p "$(dirname "$output")"
tmp_json=$(mktemp)
tmp_yaml=$(mktemp "$(dirname "$output")/.viberange-range-config.XXXXXX")
trap 'rm -f "$tmp_json" "$tmp_yaml"' EXIT

python3 - "$blocked_networks" "$range_number" >"$tmp_json" <<'PY'
import ipaddress
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
range_network = ipaddress.ip_network(f"10.{int(sys.argv[2])}.0.0/16")
try:
    document = json.loads(path.read_text())
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"invalid blocked-network JSON: {exc}")

networks = document.get("always_blocked_networks")
if not isinstance(networks, list) or not networks:
    raise SystemExit("always_blocked_networks must be a non-empty JSON array")

normalized = []
for value in networks:
    if not isinstance(value, str):
        raise SystemExit("every blocked network must be a CIDR string")
    try:
        network = ipaddress.ip_network(value, strict=True)
    except ValueError as exc:
        raise SystemExit(f"invalid canonical CIDR {value!r}: {exc}")
    if network.version != 4:
        raise SystemExit(f"IPv6 is not supported by this range policy: {value}")
    if network.overlaps(range_network):
        raise SystemExit(
            f"blocked network {network} overlaps assigned range {range_network}"
        )
    normalized.append(str(network))

if len(set(normalized)) != len(normalized):
    raise SystemExit("always_blocked_networks contains duplicate CIDRs")
json.dump({"always_blocked_networks": normalized}, sys.stdout)
PY

cp "$base_config" "$tmp_yaml"
CIDR_FILE="$tmp_json" WG_OCTET="$wireguard_client_octet" yq eval -i '
  .network.always_blocked_networks = load(strenv(CIDR_FILE)).always_blocked_networks |
  .network.rules = ([{
    "name": "Deny assigned participant access to all other range services",
    "vlan_src": "wireguard",
    "ip_last_octet_src": (strenv(WG_OCTET) | tonumber),
    "vlan_dst": "all",
    "protocol": "all",
    "ports": "all",
    "action": "REJECT"
  }] + [.network.rules[] | select(.name != "Deny assigned participant access to all other range services")]) |
  (.network.rules[] | select(.vlan_src == "wireguard") | .ip_last_octet_src) = (strenv(WG_OCTET) | tonumber)
' "$tmp_yaml"

yq eval -e '.network.always_blocked_networks | length > 0' "$tmp_yaml" >/dev/null
WG_OCTET="$wireguard_client_octet" yq eval -e '
  ([.network.rules[] | select(.vlan_src == "wireguard") |
    .ip_last_octet_src == (strenv(WG_OCTET) | tonumber)] | length > 0) and
  ([.network.rules[] | select(.vlan_src == "wireguard") |
    .ip_last_octet_src == (strenv(WG_OCTET) | tonumber)] | all) and
  ([.network.rules[] | select(.vlan_src == "wireguard" and .action == "REJECT" and .vlan_dst == "all")] | length > 0)
' "$tmp_yaml" >/dev/null
chmod 0600 "$tmp_yaml"
mv -f "$tmp_yaml" "$output"
printf 'Rendered protected range config: %s\n' "$output"
printf 'Range prefix protected from accidental blocking: 10.%s.0.0/16\n' "$range_number"
printf 'WireGuard ACCEPT rules scoped to client: 198.51.100.%s/32\n' "$wireguard_client_octet"
