#!/usr/bin/env bash
# Apply only the no-reboot Ludus controls from the WireGuard-only hardening plan.
# This script does not invoke apt, reboot, SSH, nftables/iptables, Proxmox
# networking, WireGuard, or Tailscale.
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

readonly SCRIPT_NAME="${0##*/}"
readonly EXPECTED_HOST="${EXPECTED_HOST:-}"
readonly CONFIG="${LUDUS_CONFIG:-/opt/ludus/config.yml}"
readonly DB_DIR="${LUDUS_DB_DIR:-/opt/ludus/db}"
readonly BACKUP_ROOT="${LUDUS_BACKUP_ROOT:-/root/viberange-ludus-backups}"
readonly LOCK_FILE="/run/lock/viberange-ludus-lockdown.lock"
MODE=check
BACKUP_DIR=
ORIGINAL_CONFIG=
ROLLBACK_NEEDED=false
WORK_FILE=

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: sudo ./${SCRIPT_NAME} --check
       sudo ./${SCRIPT_NAME} --apply

--check  Read-only preflight and current-state report (default).
--apply  Back up Ludus config/database, set the two controls, restart only
         ludus and ludus-admin, and validate the admin listener.

Expected host: ${EXPECTED_HOST:-<set EXPECTED_HOST to the Ludus host short name>}
Config:        ${CONFIG}
Database:      ${DB_DIR}
Backup root:   ${BACKUP_ROOT}
EOF
}

rollback() {
  local rc=$?
  trap - EXIT INT TERM
  [[ -z $WORK_FILE ]] || rm -f -- "$WORK_FILE"
  if $ROLLBACK_NEEDED && [[ -n $ORIGINAL_CONFIG && -f $ORIGINAL_CONFIG ]]; then
    log "Apply failed; restoring the original Ludus configuration."
    cp -a -- "$ORIGINAL_CONFIG" "$CONFIG"
    systemctl restart ludus ludus-admin || true
    log "Rollback attempted. Keep participant access closed and inspect both services."
  fi
  exit "$rc"
}
trap rollback EXIT INT TERM

case "${1:---check}" in
  --check) [[ $# -eq 1 || $# -eq 0 ]] || { usage >&2; exit 2; }; MODE=check ;;
  --apply) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; MODE=apply ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

[[ ${EUID} -eq 0 ]] || die "Run as root with sudo."
[[ -n $EXPECTED_HOST ]] || die "Set EXPECTED_HOST to the intended Ludus host short name."
[[ $(hostname -s) == "$EXPECTED_HOST" ]] || die "Refusing host $(hostname -s); expected ${EXPECTED_HOST}."
for command_name in awk chmod chown cp flock grep install mktemp paste ss stat systemctl; do
  command -v "$command_name" >/dev/null 2>&1 || die "Required command is missing: ${command_name}"
done
[[ -f $CONFIG && -r $CONFIG ]] || die "Ludus config is not readable: ${CONFIG}"

exec 9>"$LOCK_FILE"
flock -n 9 || die "Another Ludus lockdown run is active."

config_value() {
  local key=$1
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*#" { next }
    $0 ~ "^" key ":[[:space:]]*" {
      value=$0
      sub("^[^:]+:[[:space:]]*", "", value)
      sub("[[:space:]]+#.*$", "", value)
      print value
    }
  ' "$CONFIG"
}

require_single_boolean() {
  local key=$1 expected=$2 values count
  values=$(config_value "$key")
  count=$(printf '%s\n' "$values" | awk 'NF {count++} END {print count+0}')
  [[ $count -eq 1 ]] || die "Expected exactly one active ${key} key; found ${count}."
  [[ $values == "$expected" ]] || die "Expected ${key}: ${expected}; found ${values}."
}

admin_port=$(config_value admin_port)
if [[ -z $admin_port ]]; then
  admin_port=8081
fi
[[ $admin_port =~ ^[0-9]+$ ]] || die "Invalid admin_port in ${CONFIG}: ${admin_port}"

report_state() {
  local service setting listeners
  log "Config metadata: $(stat -c '%a %U:%G %n' "$CONFIG")"
  for setting in prevent_user_ansible_add expose_admin_port; do
    printf '%s=%s\n' "$setting" "$(config_value "$setting" | paste -sd, -)"
  done
  for service in ludus ludus-admin; do
    printf '%s=%s\n' "$service" "$(systemctl is-active "$service" 2>/dev/null || true)"
  done
  listeners=$(ss -H -ltn | awk -v port=":${admin_port}" '$4 ~ (port "$") {print $4}')
  printf 'admin_port=%s listeners=%s\n' "$admin_port" "${listeners:-none}"
}

validate_admin_listener() {
  local listeners address found=false
  listeners=$(ss -H -ltn | awk -v port=":${admin_port}" '$4 ~ (port "$") {print $4}')
  [[ -n $listeners ]] || die "No listener found on Ludus admin port ${admin_port}."
  while IFS= read -r address; do
    [[ -n $address ]] || continue
    found=true
    case "$address" in
      127.*:"$admin_port"|'[::1]':"$admin_port"|::1:"$admin_port") ;;
      *) die "Admin port ${admin_port} has a non-loopback listener: ${address}" ;;
    esac
  done <<<"$listeners"
  $found || die "No loopback listener found on Ludus admin port ${admin_port}."
}

log "Read-only Ludus lockdown preflight."
report_state
for service in ludus ludus-admin; do
  systemctl is-active --quiet "$service" || die "Required service is not active: ${service}"
done

if [[ $MODE == check ]]; then
  log "CHECK ONLY: no files or services were changed."
  exit 0
fi

stamp=$(date -u +'%Y%m%dT%H%M%SZ')
BACKUP_DIR="${BACKUP_ROOT}/${stamp}"
install -d -m 0700 "$BACKUP_ROOT" "$BACKUP_DIR"
cp -a -- "$CONFIG" "$BACKUP_DIR/config.yml"
ORIGINAL_CONFIG="$BACKUP_DIR/config.yml"
if [[ -d $DB_DIR ]]; then
  cp -a -- "$DB_DIR" "$BACKUP_DIR/db"
else
  log "WARNING: database directory not found at ${DB_DIR}; config backup only."
fi
chmod -R go-rwx "$BACKUP_DIR"
log "Protected backup created: ${BACKUP_DIR}"

WORK_FILE=$(mktemp "${CONFIG}.lockdown.XXXXXX")
awk '
  BEGIN { ansible=0; admin=0 }
  /^[[:space:]]*prevent_user_ansible_add:[[:space:]]*/ {
    if (++ansible > 1) { exit 41 }
    print "prevent_user_ansible_add: true"
    next
  }
  /^[[:space:]]*expose_admin_port:[[:space:]]*/ {
    if (++admin > 1) { exit 42 }
    print "expose_admin_port: false"
    next
  }
  { print }
  END {
    if (ansible == 0) print "prevent_user_ansible_add: true"
    if (admin == 0) print "expose_admin_port: false"
  }
' "$CONFIG" >"$WORK_FILE" || die "Could not safely render the updated Ludus config (duplicate key?)."
chown --reference="$CONFIG" "$WORK_FILE"
chmod --reference="$CONFIG" "$WORK_FILE"

ROLLBACK_NEEDED=true
cp --preserve=mode,ownership -- "$WORK_FILE" "$CONFIG"
require_single_boolean prevent_user_ansible_add true
require_single_boolean expose_admin_port false

log "Restarting only ludus and ludus-admin; host networking and Tailscale are untouched."
systemctl restart ludus ludus-admin
for _ in {1..15}; do
  if systemctl is-active --quiet ludus && systemctl is-active --quiet ludus-admin; then
    break
  fi
  sleep 1
done
systemctl is-active --quiet ludus || die "ludus did not return active."
systemctl is-active --quiet ludus-admin || die "ludus-admin did not return active."
listener_ready=false
for _ in {1..30}; do
  if ss -H -ltn | awk -v port=":${admin_port}" '$4 ~ (port "$") {found=1} END {exit !found}'; then
    validate_admin_listener
    listener_ready=true
    break
  fi
  sleep 1
done
$listener_ready || die "No listener appeared on Ludus admin port ${admin_port} within 30 seconds."

ROLLBACK_NEEDED=false
log "Ludus control-plane lockdown applied successfully."
report_state
log "Backup retained at ${BACKUP_DIR}"
log "NEXT: verify the existing instructor API tunnel before credential or range changes."
