#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
check() { printf '[*] %s... ' "$1"; }
ok() { echo 'ok'; }
bad() { echo "FAIL: $*"; fail=1; }

check 'required directories'
for d in 01-ludus-range 02-clickhouse 03-vector 04-router-evidence 05-k8s-telemetry 06-k8s-goat 07-caldera 08-experiment-framework 09-detection-and-reporting ansible/roles docs; do
  [ -d "$d" ] || bad "missing $d"
done
[ "$fail" -eq 0 ] && ok || true

check 'Ludus Source and blueprint scaffold'
for f in source.yml blueprints/viberange/blueprint.yml blueprints/viberange/range-config.yml blueprints/viberange/requirements.yml; do
  [ -f "$f" ] || bad "missing $f"
done
if command -v yq >/dev/null 2>&1; then
  for f in source.yml blueprints/viberange/blueprint.yml blueprints/viberange/range-config.yml blueprints/viberange/requirements.yml; do
    yq eval '.' "$f" >/dev/null || bad "invalid YAML: $f"
  done
fi
if command -v yq >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  blueprint_version=$(yq eval -r '.version' blueprints/viberange/blueprint.yml)
  range_version=$(yq eval -r '.ludus_extensions.viberange.blueprint_version' blueprints/viberange/range-config.yml)
  stage_version=$(jq -r '.blueprint_version' config/viberange-stages.json)
  [[ $blueprint_version == "$range_version" && $blueprint_version == "$stage_version" ]] \
    || bad "release versions disagree: blueprint=$blueprint_version range=$range_version stages=$stage_version"
fi
for f in \
  templates/viberange-kali-caldera-v1/viberange-kali-caldera-v1.pkr.hcl \
  templates/viberange-kali-caldera-v1/ansible/prepare-kali.yml \
  templates/viberange-kali-caldera-v1/http/kali-preseed.cfg; do
  [ -f "$f" ] || bad "missing $f"
done
[ "$fail" -eq 0 ] && ok || true

check 'clickhouse-ir template assets match authoritative roles'
if scripts/sync-clickhouse-ir-template-assets.sh check; then
  ok
else
  bad 'run scripts/sync-clickhouse-ir-template-assets.sh sync'
fi

check 'deployed reconstruction notebook matches framework source'
if cmp -s \
  08-experiment-framework/notebooks/viberange-reconstruction.ipynb \
  ansible/roles/ludus_jupyter/files/viberange-reconstruction.ipynb; then
  ok
else
  bad 'copy the framework reconstruction notebook into ludus_jupyter/files'
fi

check 'shell scripts syntax'
while IFS= read -r s; do
  bash -n "$s"
done < <(find scripts 07-caldera 08-experiment-framework -type f -name '*.sh' | sort)
ok

check 'production network isolation contract'
if command -v yq >/dev/null 2>&1 \
  && [ "$(yq eval '.ludus_extensions.viberange.participant_access' blueprints/viberange/range-config.yml)" = wireguard_only ] \
  && [ "$(yq eval '.ludus_extensions.viberange.requires_site_blocked_networks' blueprints/viberange/range-config.yml)" = true ] \
  && [ "$(yq eval '.ludus_extensions.viberange.requires_wireguard_client_octet' blueprints/viberange/range-config.yml)" = true ] \
  && [ "$(yq eval '([.network.rules[] | select(.vlan_src == "wireguard") | .ip_last_octet_src == 255] | length > 0) and ([.network.rules[] | select(.vlan_src == "wireguard") | .ip_last_octet_src == 255] | all) and ([.network.rules[] | select(.vlan_src == "wireguard" and .action == "REJECT" and .vlan_dst == "all")] | length > 0)' blueprints/viberange/range-config.yml)" = true ] \
  && [ "$(yq eval '.ludus_extensions.viberange.required_ludus_host_settings.prevent_user_ansible_add' blueprints/viberange/range-config.yml)" = true ] \
  && [ "$(yq eval '.ludus_extensions.viberange.required_ludus_host_settings.expose_admin_port' blueprints/viberange/range-config.yml)" = false ] \
  && [ -x scripts/render-secure-range-config.sh ] \
  && [ -x scripts/apply-ludus-control-plane-lockdown.sh ]; then
  ok
else
  bad 'WireGuard-only metadata or executable secure range renderer is missing'
fi

exit "$fail"
