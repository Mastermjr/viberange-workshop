#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
template_root="$repo_root/templates/viberange-clickhouse-ir-debian12-v1/files/bootstrap"
mode=${1:-sync}

mappings=(
  "ansible/roles/ludus_clickhouse_ir/files/schema.sql|clickhouse/schema.sql"
  "ansible/roles/ludus_clickhouse_ir/templates/network.xml.j2|clickhouse/network.xml.j2"
  "ansible/roles/ludus_clickhouse_ir/templates/clickhouse-server.service.j2|clickhouse/clickhouse-server.service.j2"
  "ansible/roles/ludus_vector_defender/files/vector-native.sql|vector/vector-native.sql"
  "ansible/roles/ludus_vector_defender/files/prepare-source-native-v1.sql|vector/prepare-source-native-v1.sql"
  "ansible/roles/ludus_vector_defender/files/prepare-tetragon-projection-v2.sql|vector/prepare-tetragon-projection-v2.sql"
  "ansible/roles/ludus_vector_defender/files/build_source_native_backfill.py|vector/build_source_native_backfill.py"
  "ansible/roles/ludus_vector_defender/templates/vector.toml.j2|vector/vector.toml.j2"
  "ansible/roles/ludus_vector_defender/templates/vector.service.j2|vector/vector.service.j2"
  "ansible/roles/ludus_router_evidence/files/pcap-artifacts.sql|router/pcap-artifacts.sql"
  "ansible/roles/ludus_run_control/files/run-control.sql|run-control/run-control.sql"
  "ansible/roles/ludus_run_control/files/reconstruction.sql|run-control/reconstruction.sql"
  "ansible/roles/ludus_jupyter/files/requirements.txt|jupyter/requirements.txt"
  "ansible/roles/ludus_ch_ui/templates/server.yaml.j2|ch-ui/server.yaml.j2"
  "ansible/roles/ludus_ch_ui/templates/ch-ui.service.j2|ch-ui/ch-ui.service.j2"
  "ansible/roles/ludus_ch_ui/templates/search-catalog.json.j2|ch-ui/search-catalog.json.j2"
  "ansible/roles/ludus_ch_ui/templates/live-evidence-dashboard.json.j2|ch-ui/live-evidence-dashboard.json.j2"
  "ansible/roles/ludus_ch_ui/templates/kubernetes-telemetry-dashboard.json.j2|ch-ui/kubernetes-telemetry-dashboard.json.j2"
  "ansible/roles/ludus_ch_ui/templates/kubernetes-telemetry-all-dashboard.json.j2|ch-ui/kubernetes-telemetry-all-dashboard.json.j2"
  "ansible/roles/ludus_ch_ui/files/seed_ch_ui.py|ch-ui/seed_ch_ui.py"
  "ansible/roles/ludus_ch_ui/files/validate_ch_ui_reader.py|ch-ui/validate_ch_ui_reader.py"
)

case "$mode" in
  sync)
    for mapping in "${mappings[@]}"; do
      src=${mapping%%|*}
      dst=${mapping#*|}
      install -D -m 0644 "$repo_root/$src" "$template_root/$dst"
    done
    ;;
  check)
    failed=0
    for mapping in "${mappings[@]}"; do
      src=${mapping%%|*}
      dst=${mapping#*|}
      if ! cmp -s "$repo_root/$src" "$template_root/$dst"; then
        printf 'stale template asset: %s (run %s sync)\n' "$dst" "$0" >&2
        failed=1
      fi
    done
    exit "$failed"
    ;;
  *)
    printf 'usage: %s [sync|check]\n' "$0" >&2
    exit 2
    ;;
esac
