#!/usr/bin/env bash
# ==============================================================================
# scan-hardware.sh - Unified Hardware Telemetry Scanner
# Generates sys-hardware.json for the provisioning driver matrix.
# ==============================================================================
set -euo pipefail

# ------------------------------------------
# HARDWARE DETECTION HELPERS
# ------------------------------------------
HAVE_LSPCI=$(command -v lspci >/dev/null && echo "true" || echo "false")

detect_nvidia() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "10de:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[10de:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1
  
  local device_dec=$((16#$device_id))
  local series="unknown"
  if (( device_dec >= 0x2200 )); then series="ada_rtx_40xx";
  elif (( device_dec >= 0x1B80 )); then series="ampere_rtx_30xx";
  elif (( device_dec >= 0x1600 )); then series="turing";
  elif (( device_dec >= 0x1380 )); then series="pascal";
  elif (( device_dec >= 0x0FC0 )); then series="maxwell";
  elif (( device_dec >= 0x0DC0 )); then series="kepler";
  fi
  
  echo '{"detected": true, "vendor": "nvidia", "series": "'"$series"'", "id": "0x'"$device_id"'"}'
}

detect_intel() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "8086:" | grep -i "vga\|3d\|display" | head -1 | grep -oP '\[8086:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1
  
  local device_dec=$((16#$device_id))
  local gen="unknown"
  if (( device_dec >= 0x7600 )); then gen="arrow_lake";
  elif (( device_dec >= 0x7D00 )); then gen="raptor_lake";
  elif (( device_dec >= 0x4600 )); then gen="alder_lake";
  elif (( device_dec >= 0x9A00 )); then gen="tiger_lake";
  elif (( device_dec >= 0x8A00 )); then gen="ice_lake";
  elif (( device_dec >= 0x5900 )); then gen="coffee_lake_9";
  elif (( device_dec >= 0x3E00 )); then gen="coffee_lake_8";
  elif (( device_dec >= 0x1900 )); then gen="skylake";
  elif (( device_dec >= 0x1600 )); then gen="broadwell";
  fi
  
  echo '{"detected": true, "vendor": "intel", "generation": "'"$gen"'", "id": "0x'"$device_id"'"}'
}

detect_amd() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local device_id=$(lspci -nn 2>/dev/null | grep -i "1002:" | grep -i "vga\|3d" | grep -v "00:02" | head -1 | grep -oP '\[1002:\K[0-9a-f]{4}' || echo "")
  [[ -z "$device_id" ]] && return 1
  
  local device_dec=$((16#$device_id))
  local series="legacy"
  (( device_dec >= 0x7300 )) && series="rdna"
  
  echo '{"detected": true, "vendor": "amd", "series": "'"$series"'", "id": "0x'"$device_id"'"}'
}

detect_wifi() {
  [[ "${HAVE_LSPCI}" == "true" ]] || return 1
  local wifi_vendor=$(lspci 2>/dev/null | grep -i "network.*wireless\|wireless.*controller" | head -1 || echo "")
  local vendor="generic"
  if echo "$wifi_vendor" | grep -qi "broadcom\|bcm"; then vendor="broadcom";
  elif echo "$wifi_vendor" | grep -qi "intel"; then vendor="intel";
  elif echo "$wifi_vendor" | grep -qi "realtek\|rtl"; then vendor="realtek";
  elif echo "$wifi_vendor" | grep -qi "atheros\|qualcomm\|qca"; then vendor="atheros";
  fi
  echo '"'"$vendor"'"'
}

detect_secure_boot() {
  if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
    echo "true"
  else
    echo "false"
  fi
}

# ------------------------------------------
# MAIN SCANNER
# ------------------------------------------
main() {
  local nvidia_data=$(detect_nvidia || echo '{"detected": false}')
  local intel_data=$(detect_intel || echo '{"detected": false}')
  local amd_data=$(detect_amd || echo '{"detected": false}')
  local wifi_vendor=$(detect_wifi)
  local secure_boot=$(detect_secure_boot)
  local hybrid=$( ( [[ $(echo "$nvidia_data" | jq -r .detected) == "true" ]] && [[ $(echo "$intel_data" | jq -r .detected) == "true" ]] ) && echo "true" || echo "false" )

  cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gpu": {
    "nvidia": $nvidia_data,
    "intel": $intel_data,
    "amd": $amd_data,
    "hybrid_mode": $hybrid
  },
  "network": {
    "wifi_vendor": $wifi_vendor
  },
  "system": {
    "secure_boot_enabled": $secure_boot
  }
}
EOF
}

main > sys-hardware.json
echo "[OK] Hardware telemetry generated: sys-hardware.json"
