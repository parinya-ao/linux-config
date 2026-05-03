#!/usr/bin/env bash
# lib/system.sh

check_requirements() {
    log_step "Validating system environment..."
    
    if ! timeout 5s curl -sI https://github.com >/dev/null; then
        abort "No internet connection to GitHub."
    fi

    local free_space
    free_space=$(df -k . | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 2097152 ]; then
        abort "Insufficient disk space (< 2GB free)."
    fi
    log_ok "System validation passed."
}
