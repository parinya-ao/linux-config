#!/usr/bin/env bash
# ==============================================================================
# Script: firefox-esr.sh
# Description: Production-grade automated installer for Firefox ESR (Fedora Copr)
# Architecture: Modular, KISS, State-driven, Integration Tested
# ==============================================================================

# Strict mode: fail on error, undefined vars, and pipe failures
set -euo pipefail

# --- Global Configurations ---
readonly LOG_FILE="/var/log/firefox_esr_install.log"
CURRENT_STATE="INIT"

# --- ANSI Color Codes ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_NC='\033[0m' # No Color

# --- Logging Framework ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1" | tee -a "$LOG_FILE"; }
log_info()    { log "${C_BLUE}[INFO]${C_NC} $1"; }
log_success() { log "${C_GREEN}[SUCCESS]${C_NC} $1"; }
log_error()   { log "${C_RED}[ERROR]${C_NC} $1"; }
log_debug()   { log "${C_YELLOW}[DEBUG]${C_NC} [STATE: ${C_MAGENTA}${CURRENT_STATE}${C_NC}] $1"; }

# --- State Transition Trap ---
error_handler() {
    log_error "Script failed during state: ${CURRENT_STATE}. Please check ${LOG_FILE} for details."
    exit 1
}
trap 'error_handler' ERR

# --- Modular Functions ---

check_privileges() {
    CURRENT_STATE="CHECK_PRIVILEGES"
    # ทำการเช็คสิทธิ์ก่อนโดยใช้ echo ธรรมดา (ยังไม่เรียก log function เพราะยังไม่มีไฟล์ log)
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${C_RED}[ERROR]${C_NC} This script must be run as root or with sudo." >&2
        exit 1
    fi
}

install_prerequisites() {
    CURRENT_STATE="INSTALL_PREREQ"
    log_debug "Ensuring dnf-plugins-core is installed..."
    
    if ! command -v dnf >/dev/null 2>&1; then
        log_error "DNF package manager not found. This script is intended for Fedora/RHEL derivatives."
        exit 1
    fi

    dnf install -y dnf-plugins-core >> "$LOG_FILE" 2>&1
    
    # State Validation
    if dnf copr --help >/dev/null 2>&1; then
        log_success "Prerequisites installed. DNF Copr plugin is available."
    else
        log_error "Failed to validate DNF Copr plugin availability."
        exit 1
    fi
}

enable_copr_repo() {
    CURRENT_STATE="ENABLE_REPO"
    local repo_target="erizur/firefox-esr"
    log_debug "Enabling Copr repository: ${repo_target}..."
    
    dnf copr enable -y "${repo_target}" >> "$LOG_FILE" 2>&1
    
    # State Validation
    log_debug "Verifying repository integration..."
    if dnf repolist | grep -qi "erizur.*firefox-esr"; then
        log_success "Copr repository ${repo_target} successfully enabled and verified."
    else
        log_error "Repository ${repo_target} not found in dnf repolist."
        exit 1
    fi
}

install_package() {
    CURRENT_STATE="INSTALL_PACKAGE"
    local pkg_name="firefox-esr"
    log_debug "Executing installation for ${pkg_name}..."
    
    dnf install -y "${pkg_name}" >> "$LOG_FILE" 2>&1
    
    # State Validation
    if rpm -q "${pkg_name}" >/dev/null 2>&1; then
        log_success "Package ${pkg_name} installed via RPM database."
    else
        log_error "Package installation failed. RPM database does not show ${pkg_name}."
        exit 1
    fi
}

# --- System Integration Testing Phase ---
integration_test() {
    CURRENT_STATE="INTEGRATION_TEST"
    log_debug "Initiating system integration tests..."
    
    local binary_path
    binary_path=$(command -v firefox-esr || true)
    
    # Test 1: Binary Existence and Path
    if [[ -z "$binary_path" || ! -f "$binary_path" ]]; then
        log_error "[Test 1 Failed] Executable 'firefox-esr' not found in PATH."
        exit 1
    fi
    log_success "[Test 1 Passed] Binary located at: ${binary_path}"
    
    # Test 2: Execution Permission
    if [[ ! -x "$binary_path" ]]; then
        log_error "[Test 2 Failed] Binary lacks execution permissions."
        exit 1
    fi
    log_success "[Test 2 Passed] Execution permissions verified."
    
    # Test 3: Version Output Validation
    local version_output
    version_output=$($binary_path --version 2>&1 || true)
    if echo "$version_output" | grep -qi "Mozilla Firefox"; then
        log_success "[Test 3 Passed] Version output verified: ${version_output}"
    else
        log_error "[Test 3 Failed] Unexpected version output: ${version_output}"
        exit 1
    fi

    log_success "All system integration tests passed flawlessly."
}

# --- Main Execution ---
main() {
    # 1. เช็คสิทธิ์เป็นอันดับแรกสุด ป้องกันการระเบิดจาก touch /var/log
    check_privileges
    
    # 2. เมื่อมั่นใจว่าเป็น Root แล้วจึงสร้าง Log File
    touch "$LOG_FILE" || { echo "Cannot write to ${LOG_FILE}. Exiting."; exit 1; }
    
    # 3. เริ่มต้นกระบวนการที่เหลือและเริ่ม Log ได้อย่างปลอดภัย
    log_info "Starting Automated Deployment of Firefox ESR"
    log_success "Root privileges confirmed."
    
    install_prerequisites
    enable_copr_repo
    install_package
    integration_test
    
    CURRENT_STATE="DONE"
    log_info "Deployment completed successfully. Firefox ESR is ready for use."
}

# Execute
main "$@"
