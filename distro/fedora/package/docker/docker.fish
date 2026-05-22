#!/usr/bin/env fish
# ==============================================================================
# Script: docker.fish
# Purpose: Production-grade Docker installer for Fedora
# Architecture: Modular, Open, KISS. State-validated step-by-step.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Globals & Configuration
# ------------------------------------------------------------------------------
set LOG_FILE "/tmp/docker_install_"(date +%s)".log"

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
    
    if not command -v dnf >/dev/null 2>&1
        fail_exit "'dnf' package manager not found. This script requires Fedora."
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
    
    set -l packages docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
    
    sudo dnf remove -y $packages >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "Old versions removed or not present."
    else
        log_msg "WARN" "Non-fatal issue removing old versions. Proceeding anyway."
    end
end

function setup_repository
    log_msg "DEBUG" "Setting up Docker CE repository..."
    
    sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo >> $LOG_FILE 2>&1
    if test $status -eq 0
        log_msg "OK" "Docker repository added successfully."
    else
        fail_exit "Failed to add Docker repository."
    end
end

function install_docker_packages
    log_msg "DEBUG" "Installing Docker Engine, CLI, Containerd, and Plugins..."
    
    sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y >> $LOG_FILE 2>&1
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
        log_msg "WARN" "Failed to start service normally. Checking alternative iptables-nft fallback..."
        sudo alternatives --set iptables /usr/bin/iptables-nft >> $LOG_FILE 2>&1
        sudo systemctl restart docker >> $LOG_FILE 2>&1
        if test $status -eq 0
            log_msg "OK" "Docker service started using iptables-nft fallback."
        else
            fail_exit "Failed to start Docker service completely."
        end
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
    log_msg "INFO" "Starting Docker installation process on Fedora..."
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

# Execute main function
main
