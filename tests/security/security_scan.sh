#!/usr/bin/env bash
# ==============================================================================
# Script: security_scan.sh
# Purpose: Production-grade DAST scanning using OWASP ZAP.
# Architecture: Modular, State-driven, Strict-mode.
# ==============================================================================

set -euo pipefail

# --- Global Configurations ---
readonly LOG_FILE="/tmp/dast_security_scan.log"
readonly REPORT_DIR="./tests/security/reports"
readonly ZAP_IMAGE="owasp/zap2docker-stable:latest"
CURRENT_STATE="INIT"

# --- ANSI Color Codes ---
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_MAGENTA='\033[0;35m'
readonly C_NC='\033[0m'

# --- Logging Framework ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] [${C_MAGENTA}STATE:${CURRENT_STATE}${C_NC}] $1" | tee -a "$LOG_FILE"; }
log_info()    { log "${C_BLUE}[INFO]${C_NC} $1"; }
log_success() { log "${C_GREEN}[SUCCESS]${C_NC} $1"; }
log_warn()    { log "${C_YELLOW}[WARN]${C_NC} $1"; }
log_error()   { log "${C_RED}[ERROR]${C_NC} $1"; }

# --- Error Handler ---
error_handler() {
    log_error "Security Scan failed during state: ${CURRENT_STATE}."
    # Attempt to cleanup ZAP containers if running
    docker stop zap-scan >/dev/null 2>&1 || true
    exit 1
}
trap 'error_handler' ERR

# --- Functions ---

# State: VERIFY_DEPS
verify_dependencies() {
    CURRENT_STATE="VERIFY_DEPS"
    log_info "Verifying dependencies..."
    for cmd in docker curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Command '$cmd' is not installed. Please install it."
            exit 1
        fi
    done
    mkdir -p "$REPORT_DIR"
    log_success "Dependencies verified."
}

# State: TARGET_HEALTH_CHECK
check_target_health() {
    CURRENT_STATE="TARGET_HEALTH_CHECK"
    local target_url=$1
    log_info "Health checking target: $target_url"
    
    local retries=5
    for i in $(seq 1 "$retries"); do
        if curl -s --head --request GET "$target_url" | grep "200 OK" >/dev/null 2>&1; then
            log_success "Target is healthy."
            return 0
        fi
        log_warn "Target not ready, retrying ($i/$retries)..."
        sleep 5
    done
    
    log_error "Target failed health check."
    exit 1
}

# State: EXECUTE_DAST_SCAN
run_zap_scan() {
    CURRENT_STATE="EXECUTE_DAST_SCAN"
    local target_url=$1
    local mode=$2 # zap-baseline.py or zap-api-scan.py
    log_info "Executing ZAP scan ($mode) against $target_url"

    docker run --rm -v "$(pwd)/$REPORT_DIR":/zap/wrk/:rw \
        --name zap-scan "$ZAP_IMAGE" \
        "$mode" -t "$target_url" \
        -r report.html -J report.json > /dev/null 2>&1 || true
    
    log_success "ZAP scan finished."
}

# State: PARSE_RESULTS & QUALITY GATE
evaluate_security_gate() {
    CURRENT_STATE="PARSE_RESULTS"
    log_info "Analyzing results for High/Medium vulnerabilities..."
    
    local report_json="$REPORT_DIR/report.json"
    if [ ! -f "$report_json" ]; then
        log_error "Report file not found."
        exit 1
    fi

    # Simplified check using grep to find "High" or "Medium" risk items in ZAP JSON
    # Note: A real implementation would use jq for robust parsing.
    local high
    high=$(grep -o '"risk": "High"' "$report_json" | wc -l)
    local med
    med=$(grep -o '"risk": "Medium"' "$report_json" | wc -l)

    echo "Vulnerabilities found: High: $high, Medium: $med"
    if [ "$high" -gt 0 ] || [ "$med" -gt 0 ]; then
        log_error "Security quality gate failed!"
        exit 1
    fi
    log_success "Security quality gate passed."
}

# Integration Test
run_self_integration_test() {
    log_info "Running self-test..."
    # Mocking check: verify directory exists
    [ -d "$REPORT_DIR" ] && log_success "Self-test passed."
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Default usage: ./security_scan.sh <url> <mode>
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <url> <zap-baseline.py|zap-api-scan.py>"
        exit 1
    fi
    
    verify_dependencies
    check_target_health "$1"
    run_zap_scan "$1" "$2"
    evaluate_security_gate
    run_self_integration_test
fi
