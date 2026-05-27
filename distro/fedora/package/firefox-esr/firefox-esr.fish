#!/usr/bin/env fish
# ==============================================================================
# Script: firefox-esr.fish
# Description: Production-grade automated installer for Firefox ESR (Fedora Copr)
# Architecture: Modular, KISS, State-driven, Integration Tested
# ==============================================================================

# --- Global Configurations ---
# กำหนดค่าเป็นตัวแปร Global
set -g LOG_FILE "/var/log/firefox_esr_install.log"
set -g CURRENT_STATE "INIT"

# --- Logging Framework ---
function log_msg
    set -l color $argv[1]
    set -l level $argv[2]
    set -l msg $argv[3]
    set -l timestamp (date +'%Y-%m-%dT%H:%M:%S%z')
    
    set_color $color
    echo -n "[$level] "
    set_color normal
    if test "$level" = "DEBUG"
        set_color magenta
        echo -n "[STATE: $CURRENT_STATE] "
        set_color normal
    end
    echo "$msg"
    
    # Append to log file safely
    echo "[$timestamp] [$level] [STATE: $CURRENT_STATE] $msg" >> $LOG_FILE
end

function log_info;    log_msg blue "INFO" $argv; end
function log_success; log_msg green "SUCCESS" $argv; end
function log_error;   log_msg red "ERROR" $argv; end
function log_debug;   log_msg yellow "DEBUG" $argv; end

# --- Modular Functions ---

function check_privileges
    set CURRENT_STATE "CHECK_PRIVILEGES"
    # เช็คสิทธิ์และแจ้งเตือนก่อนที่จะมีการยุ่งกับไฟล์ Log ใดๆ
    if test (id -u) -ne 0
        set_color red
        echo "[ERROR] This script must be run as root or with sudo." >&2
        set_color normal
        exit 1
    end
end

function install_prerequisites
    set CURRENT_STATE "INSTALL_PREREQ"
    log_debug "Ensuring dnf-plugins-core is installed..."
    
    if not command -v dnf >/dev/null 2>&1
        log_error "DNF package manager not found. Intended for Fedora derivatives."
        exit 1
    end

    dnf install -y dnf-plugins-core >> $LOG_FILE 2>&1
    
    # State Validation
    if dnf copr --help >/dev/null 2>&1
        log_success "Prerequisites installed. DNF Copr plugin is functional."
    else
        log_error "Failed to validate DNF Copr plugin availability."
        exit 1
    end
end

function enable_copr_repo
    set CURRENT_STATE "ENABLE_REPO"
    set -l repo_target "erizur/firefox-esr"
    log_debug "Enabling Copr repository: $repo_target..."
    
    dnf copr enable -y $repo_target >> $LOG_FILE 2>&1
    
    # State Validation
    log_debug "Verifying repository integration..."
    if dnf repolist | grep -qi "erizur.*firefox-esr"
        log_success "Copr repository $repo_target enabled and verified."
    else
        log_error "Repository $repo_target not found in dnf repolist."
        exit 1
    end
end

function install_package
    set CURRENT_STATE "INSTALL_PACKAGE"
    set -l pkg_name "firefox-esr"
    log_debug "Executing installation for $pkg_name..."
    
    dnf install -y $pkg_name >> $LOG_FILE 2>&1
    
    # State Validation
    if rpm -q $pkg_name >/dev/null 2>&1
        log_success "Package $pkg_name verified via RPM database."
    else
        log_error "Package installation failed. RPM database missing $pkg_name."
        exit 1
    end
end

# --- System Integration Testing Phase ---
function integration_test
    set CURRENT_STATE "INTEGRATION_TEST"
    log_debug "Initiating system integration tests..."
    
    set -l binary_path (command -v firefox-esr)
    
    # Test 1: Binary Existence
    if test -z "$binary_path"; or not test -f "$binary_path"
        log_error "[Test 1 Failed] Executable 'firefox-esr' not found in PATH."
        exit 1
    end
    log_success "[Test 1 Passed] Binary located at: $binary_path"
    
    # Test 2: Execution Permission
    if not test -x "$binary_path"
        log_error "[Test 2 Failed] Binary lacks execution permissions."
        exit 1
    end
    log_success "[Test 2 Passed] Execution permissions verified."
    
    # Test 3: Version Output Validation
    set -l version_output (eval "$binary_path --version" 2>&1)
    if echo "$version_output" | grep -qi "Mozilla Firefox"
        log_success "[Test 3 Passed] Version output verified: $version_output"
    else
        log_error "[Test 3 Failed] Unexpected version output: $version_output"
        exit 1
    end

    log_success "All system integration tests passed flawlessly."
end

# --- Main Execution ---
function main
    # 1. เช็คสิทธิ์และปฏิเสธทันทีถ้าไม่ใช่ Root
    check_privileges
    
    # 2. ปลอดภัยที่จะสัมผัสไฟล์ log แล้ว
    if not touch $LOG_FILE 2>/dev/null
        echo "Cannot write to $LOG_FILE. Exiting."
        exit 1
    end
    
    # 3. แจ้งสถานะและเริ่มลุยสเตตัสอื่นๆ
    log_info "Starting Automated Deployment of Firefox ESR (Fish Environment)"
    log_success "Root privileges confirmed."
    
    install_prerequisites
    enable_copr_repo
    install_package
    integration_test
    
    set CURRENT_STATE "DONE"
    log_info "Deployment completed successfully. Firefox ESR is ready for use."
end

# Execute
main
