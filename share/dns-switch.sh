#!/usr/bin/env bash
set -Eeuo pipefail

# dns-switch.sh
# KISS + modular + cross-distro
# Supported:
# - Ubuntu / Debian (Netplan or NetworkManager)
# - Fedora / RHEL / CentOS Stream (NetworkManager)
# - openSUSE (NetworkManager or wicked/netconfig)
#
# Usage examples:
#   sudo bash dns-switch.sh apply cloudflare-family
#   sudo bash dns-switch.sh apply google
#   sudo bash dns-switch.sh apply quad9
#   sudo bash dns-switch.sh apply custom "8.8.8.8 8.8.4.4" "2001:4860:4860::8888 2001:4860:4860::8844"
#   sudo bash dns-switch.sh show
#   sudo bash dns-switch.sh backup
#
# Notes:
# - Avoid editing /etc/resolv.conf directly unless you truly own resolver generation.
# - This script tries native backend first for persistence.

STATE_DIR="/etc/dns-switch"
BACKUP_DIR="${STATE_DIR}/backup"

mkdir -p "$STATE_DIR" "$BACKUP_DIR"

log()  { printf '[INFO] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERR ] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Please run as root."
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  OS_ID="unknown"
  OS_LIKE=""
  OS_VER=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_VER="${VERSION_ID:-}"
  fi
}

detect_backend() {
  BACKEND="unknown"

  # 1) Netplan first when config exists and command is available
  if cmd_exists netplan && compgen -G "/etc/netplan/*.yaml" >/dev/null; then
    BACKEND="netplan"
    return
  fi

  # 2) NetworkManager when service/cli exists
  if cmd_exists nmcli; then
    if systemctl is-active --quiet NetworkManager 2>/dev/null || systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
      BACKEND="nmcli"
      return
    fi
    BACKEND="nmcli"
    return
  fi

  # 3) wicked/netconfig on SUSE family
  if cmd_exists netconfig && [[ -f /etc/sysconfig/network/config ]]; then
    BACKEND="wicked"
    return
  fi

  BACKEND="unknown"
}

default_provider_data() {
  PROVIDER="${1:-cloudflare-family}"
  DNS_V4=""
  DNS_V6=""

  case "$PROVIDER" in
    cloudflare-family)
      DNS_V4="1.1.1.3 1.0.0.3"
      DNS_V6="2606:4700:4700::1113 2606:4700:4700::1003"
      ;;
    cloudflare-malware)
      DNS_V4="1.1.1.2 1.0.0.2"
      DNS_V6="2606:4700:4700::1112 2606:4700:4700::1002"
      ;;
    google)
      DNS_V4="8.8.8.8 8.8.4.4"
      DNS_V6="2001:4860:4860::8888 2001:4860:4860::8844"
      ;;
    quad9)
      DNS_V4="9.9.9.9 149.112.112.112"
      DNS_V6="2620:fe::fe 2620:fe::9"
      ;;
    opendns-family)
      DNS_V4="208.67.222.123 208.67.220.123"
      DNS_V6=""
      ;;
    adguard-family)
      DNS_V4="94.140.14.15 94.140.15.16"
      DNS_V6=""
      ;;
    custom)
      DNS_V4="${2:-}"
      DNS_V6="${3:-}"
      [[ -n "$DNS_V4" || -n "$DNS_V6" ]] || die "custom requires IPv4 or IPv6 DNS values."
      ;;
    *)
      die "Unknown provider: $PROVIDER"
      ;;
  esac
}

backup_file() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  local dst="${BACKUP_DIR}/${src//\//_}.bak"
  cp -a "$src" "$dst"
}

backup_all() {
  log "Backing up known network config files..."
  backup_file /etc/os-release
  backup_file /etc/resolv.conf
  backup_file /etc/sysconfig/network/config

  if compgen -G "/etc/netplan/*.yaml" >/dev/null; then
    for f in /etc/netplan/*.yaml; do
      backup_file "$f"
    done
  fi

  if [[ -d /etc/NetworkManager/system-connections ]]; then
    tar -C /etc/NetworkManager -czf "${BACKUP_DIR}/NetworkManager-system-connections.tgz" system-connections 2>/dev/null || true
  fi

  log "Backup completed at $BACKUP_DIR"
}

show_status() {
  detect_os
  detect_backend

  echo "OS_ID=${OS_ID}"
  echo "OS_LIKE=${OS_LIKE}"
  echo "OS_VER=${OS_VER}"
  echo "BACKEND=${BACKEND}"
  echo

  if cmd_exists resolvectl; then
    resolvectl status || true
    echo
  fi

  if [[ -L /etc/resolv.conf ]]; then
    echo "/etc/resolv.conf -> $(readlink -f /etc/resolv.conf)"
  else
    echo "/etc/resolv.conf is a regular file"
  fi
  echo
  grep -E '^(search|nameserver)' /etc/resolv.conf 2>/dev/null || true
}

get_primary_nm_connection() {
  local conn=""
  conn="$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: '$2 != "" {print $1; exit}')"
  [[ -n "$conn" ]] || die "No active NetworkManager connection found."
  printf '%s\n' "$conn"
}

nmcli_apply_dns() {
  local dns4="$1"
  local dns6="$2"
  local conn
  conn="$(get_primary_nm_connection)"

  log "Using NetworkManager connection: $conn"

  if [[ -n "$dns4" ]]; then
    nmcli connection modify "$conn" ipv4.ignore-auto-dns yes
    nmcli connection modify "$conn" ipv4.dns "$dns4"
  fi

  if [[ -n "$dns6" ]]; then
    nmcli connection modify "$conn" ipv6.ignore-auto-dns yes
    nmcli connection modify "$conn" ipv6.dns "$dns6"
  fi

  nmcli connection up "$conn" || nmcli device reapply "$(nmcli -t -f DEVICE connection show --active | head -n1 | cut -d: -f1)" || true
  log "NetworkManager DNS updated."
}

netplan_pick_file() {
  local file=""
  file="$(ls -1 /etc/netplan/*.yaml 2>/dev/null | head -n1 || true)"
  [[ -n "$file" ]] || die "No netplan YAML found in /etc/netplan/"
  printf '%s\n' "$file"
}

netplan_pick_iface() {
  local file="$1"
  local iface=""
  iface="$(awk '
    /^\s*ethernets:\s*$/ {in_eth=1; next}
    in_eth && /^\s*[a-zA-Z0-9._:-]+:\s*$/ {gsub(":","",$1); gsub(/^[[:space:]]+/,"",$1); print $1; exit}
  ' "$file")"
  [[ -n "$iface" ]] || iface="$(ip -o link show | awk -F': ' '$2 !~ /lo/ {print $2; exit}')"
  [[ -n "$iface" ]] || die "Cannot detect interface for netplan."
  printf '%s\n' "$iface"
}

netplan_apply_dns() {
  local dns4="$1"
  local dns6="$2"
  local file iface tmp dns4_yaml dns6_yaml
  file="$(netplan_pick_file)"
  iface="$(netplan_pick_iface "$file")"
  tmp="$(mktemp)"

  log "Using Netplan file: $file"
  log "Using interface: $iface"

  dns4_yaml=""
  dns6_yaml=""

  if [[ -n "$dns4" ]]; then
    while read -r ip; do
      [[ -n "$ip" ]] && dns4_yaml="${dns4_yaml}          - ${ip}"$'\n'
    done <<< "$(printf '%s\n' $dns4)"
  fi

  if [[ -n "$dns6" ]]; then
    while read -r ip; do
      [[ -n "$ip" ]] && dns6_yaml="${dns6_yaml}          - ${ip}"$'\n'
    done <<< "$(printf '%s\n' $dns6)"
  fi

  cp -a "$file" "$tmp"

  # If nameservers block exists under iface, replace only addresses list.
  # Otherwise append a simple nameservers block under iface.
  if awk "/^[[:space:]]*${iface}:[[:space:]]*$/,/^[[:space:]]*[a-zA-Z0-9._:-]+:[[:space:]]*$/" "$tmp" | grep -q 'nameservers:'; then
    awk -v iface="$iface" -v dns4_yaml="$dns4_yaml" -v dns6_yaml="$dns6_yaml" '
      BEGIN{in_if=0; in_ns=0; skip_addr=0}
      {
        line=$0

        if (match(line, "^[[:space:]]*" iface ":[[:space:]]*$")) {in_if=1; print line; next}

        if (in_if && match(line, "^[[:space:]]*[a-zA-Z0-9._:-]+:[[:space:]]*$") && !match(line, "^[[:space:]]+")) {
          in_if=0; in_ns=0; skip_addr=0
        }

        if (in_if && match(line, "^[[:space:]]*nameservers:[[:space:]]*$")) {
          in_ns=1; skip_addr=0; print line; next
        }

        if (in_if && in_ns && match(line, "^[[:space:]]*addresses:[[:space:]]*$")) {
          print "        addresses:"
          if (dns4_yaml != "") printf "%s", dns4_yaml
          if (dns6_yaml != "") printf "%s", dns6_yaml
          skip_addr=1
          next
        }

        if (skip_addr && match(line, "^[[:space:]]*-[[:space:]]")) next

        if (skip_addr && !match(line, "^[[:space:]]*-[[:space:]]")) skip_addr=0

        print line
      }
    ' "$tmp" > "${tmp}.new"
  else
    awk -v iface="$iface" -v dns4_yaml="$dns4_yaml" -v dns6_yaml="$dns6_yaml" '
      BEGIN{in_if=0; injected=0}
      {
        print $0
        if (match($0, "^[[:space:]]*" iface ":[[:space:]]*$")) {
          in_if=1
          next
        }

        if (in_if && !injected && match($0, "^[[:space:]]*[a-zA-Z0-9._:-]+:[[:space:]]*$") && !match($0, "^[[:space:]]+")) {
          print "      nameservers:"
          print "        addresses:"
          if (dns4_yaml != "") printf "%s", dns4_yaml
          if (dns6_yaml != "") printf "%s", dns6_yaml
          injected=1
          in_if=0
        }
      }
      END{
        if (in_if && !injected) {
          print "      nameservers:"
          print "        addresses:"
          if (dns4_yaml != "") printf "%s", dns4_yaml
          if (dns6_yaml != "") printf "%s", dns6_yaml
        }
      }
    ' "$tmp" > "${tmp}.new"
  fi

  cp -a "${tmp}.new" "$file"
  netplan apply
  rm -f "$tmp" "${tmp}.new"
  log "Netplan DNS updated."
}

wicked_set_kv() {
  local key="$1"
  local value="$2"
  local file="/etc/sysconfig/network/config"

  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|g" "$file"
  else
    printf '%s="%s"\n' "$key" "$value" >> "$file"
  fi
}

wicked_apply_dns() {
  local dns4="$1"
  local dns6="$2"
  local all_dns=""
  [[ -n "$dns4" ]] && all_dns="$dns4"
  [[ -n "$dns6" ]] && all_dns="${all_dns:+$all_dns }$dns6"

  [[ -n "$all_dns" ]] || die "No DNS values provided for wicked backend."

  wicked_set_kv "NETCONFIG_DNS_POLICY" "STATIC"
  wicked_set_kv "NETCONFIG_DNS_STATIC_SERVERS" "$all_dns"
  netconfig update -f
  log "wicked/netconfig DNS updated."
}

apply_dns() {
  local provider="$1"
  local custom4="${2:-}"
  local custom6="${3:-}"

  detect_os
  detect_backend
  default_provider_data "$provider" "$custom4" "$custom6"

  log "Detected OS: ${OS_ID} ${OS_VER}"
  log "Detected backend: ${BACKEND}"
  log "Provider: ${provider}"
  log "IPv4 DNS: ${DNS_V4:-<none>}"
  log "IPv6 DNS: ${DNS_V6:-<none>}"

  case "$BACKEND" in
    netplan) netplan_apply_dns "$DNS_V4" "$DNS_V6" ;;
    nmcli)   nmcli_apply_dns "$DNS_V4" "$DNS_V6" ;;
    wicked)  wicked_apply_dns "$DNS_V4" "$DNS_V6" ;;
    *)
      die "No supported backend detected on this machine."
      ;;
  esac

  echo
  show_status
}

usage() {
  cat <<'EOF'
dns-switch.sh - simple cross-distro DNS switcher

Commands:
  apply <provider> [custom_ipv4_list] [custom_ipv6_list]
  show
  backup

Providers:
  cloudflare-family
  cloudflare-malware
  google
  quad9
  opendns-family
  adguard-family
  custom

Examples:
  sudo bash dns-switch.sh apply cloudflare-family
  sudo bash dns-switch.sh apply google
  sudo bash dns-switch.sh apply custom "8.8.8.8 8.8.4.4" "2001:4860:4860::8888 2001:4860:4860::8844"
  sudo bash dns-switch.sh show
  sudo bash dns-switch.sh backup
EOF
}

main() {
  require_root

  local cmd="${1:-}"
  case "$cmd" in
    apply)
      local provider="${2:-cloudflare-family}"
      backup_all
      apply_dns "$provider" "${3:-}" "${4:-}"
      ;;
    show)
      show_status
      ;;
    backup)
      backup_all
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
