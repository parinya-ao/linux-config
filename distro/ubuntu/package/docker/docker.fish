#!/usr/bin/env fish
# ==============================================================================
# Script: docker.fish
# Purpose: Production-grade Docker installer for Ubuntu
# Architecture: Modular, Open, KISS. State-validated step-by-step.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Globals & Configuration
# ------------------------------------------------------------------------------
set LOG_FILE "/tmp/docker_install_ubuntu_"(date +%s)".log"

if test -n "$SUDO_USER"
    set TARGET_USER $SUDO_USER
else
    set TARGET_USER $USER
end

# ------------------------------------------------------------------------------
# 2. Logging & Monitoring Subsystem
# ------------------------------------------------------------------------------
function log_msg
    set -l level $argv[1]
    set -l msg $argv[2]
    set -l timestamp (date "+%Y-%m-%d %H:%M:%S")

    # Write plain text to log file
    echo "[$timestamp] [$level] $msg" >> $LOG_FILE

    # Write colored text to console
    switch $level
        case "INFO"
            set_color blue; echo "[*] [$timestamp] INFO: $msg"; set_color normal
        case "OK"
            set_color green; echo "[+] [$timestamp] SUCCESS: $msg"; set_color normal
        case "WARN"
            set_color yellow; echo "[!] [$timestamp] WARN: $msg"; set_color normal
        case "ERR"
            set_color red; echo "[X] [$timestamp] ERROR: $msg" >&2; set_color normal
        case "DEBUG"
            set_color yellow; echo "[~] [$timestamp] DEBUG: $msg"; set_color normal
    end
end

function fail_exit
    log_msg "ERR" $argv[1]
    log_msg "INFO" "Installation aborted. Check $LOG_FILE for details."
    exit 1
end

# ------------------------------------------------------------------------------
# 3. Validation & State Checks
# ------------------------------------------------------------------------------
function check_prerequisites
    log_msg "DEBUG" "Checking system prerequisites..."
    if not command -v apt-get >/dev/null 2>&1
        fail_exit "'apt' package manager not found. This script requires Ubuntu/Debian."
    end
    if not sudo -v >/dev/null 2>&1
        fail_exit "Current user ($TARGET_USER) does not have sudo privileges."
    end
    log_msg "OK" "Prerequisites verified."
end

# ------------------------------------------------------------------------------
# 4. Core Modules
# ------------------------------------------------------------------------------
function remove_old_versions
    log_msg "DEBUG" "Attempting to remove conflicting/old Docker packages..."
    set -l packages docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc
    for pkg in $packages
        sudo apt-get remove -y $pkg >> $LOG_FILE 2>&1
    end
    log_msg "OK" "Conflicting versions audit completed."
end

function setup_repository
    log_msg "DEBUG" "Setting up Docker official GPG key and repository..."
    sudo apt-get update -y >> $LOG_FILE 2>&1
    sudo apt-get install -y ca-certificates curl >> $LOG_FILE 2>&1
    sudo install -m 0755 -d /etc/apt/keyrings >> $LOG_FILE 2>&1
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >> $LOG_FILE 2>&1
    sudo chmod a+r /etc/apt/keyrings/docker.asc >> $LOG_FILE 2>&1

    set -l codename (sh -c '. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"')
    set -l arch (dpkg --print-architecture)

    echo "Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc" | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

    sudo apt-get update -y >> $LOG_FILE 2>&1
    log_msg "OK" "Docker repository and GPG key configured."
end

function install_docker_packages
    log_msg "DEBUG" "Installing Docker Engine, CLI, Containerd, and Plugins..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "Docker packages installed successfully."
    else
        fail_exit "Failed to install Docker packages."
    end
end

function configure_and_start_service
    log_msg "DEBUG" "Enabling and starting Docker service..."
    sudo systemctl enable --now docker >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "Docker service enabled and started."
    else
        fail_exit "Failed to start Docker service."
    end
end

function configure_user_group
    log_msg "DEBUG" "Configuring user permissions for: $TARGET_USER"
    if not grep -q "^docker:" /etc/group
        sudo groupadd docker >> $LOG_FILE 2>&1
    end
    sudo usermod -aG docker $TARGET_USER >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "User $TARGET_USER added to 'docker' group."
    else
        fail_exit "Failed to add $TARGET_USER to docker group."
    end
end

function verify_installation
    log_msg "DEBUG" "Verifying Docker state..."
    sudo docker run --rm hello-world >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "Docker is fully operational. Hello-world container executed successfully."
    else
        fail_exit "Docker verification failed. Cannot run hello-world."
    end
end

# ------------------------------------------------------------------------------
# 5. Main Orchestrator
# ------------------------------------------------------------------------------
function main
    log_msg "INFO" "Starting Docker installation process on Ubuntu..."
    log_msg "INFO" "Detailed logs are being written to: $LOG_FILE"
    check_prerequisites
    remove_old_versions
    setup_repository
    install_docker_packages
    configure_and_start_service
    configure_user_group
    verify_installation
    echo "======================================================================"
    log_msg "OK" "Installation completed successfully!"
    log_msg "INFO" "NOTE: You must log out and log back in (or run 'newgrp docker') for the group changes to take effect."
    echo "======================================================================"
end

main
