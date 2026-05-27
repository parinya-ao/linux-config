#!/usr/bin/env bash
# ==============================================================================
# Script: tests/scripts/run-integration.sh
# Purpose: Orchestrate containerized database integration tests.
# ==============================================================================

set -uo pipefail

# ANSI Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_NC='\033[0m'

# Load Config
CONFIG_FILE="tests/integration/test-config.toml"
CURRENT_STATE="INIT"

log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')] [${CURRENT_STATE}] $1"; }
log_info() { log "${C_BLUE}[INFO]${C_NC} $1"; }
log_success() { log "${C_GREEN}[SUCCESS]${C_NC} $1"; }
log_warn() { log "${C_YELLOW}[WARN]${C_NC} $1"; }
log_error() { log "${C_RED}[ERROR]${C_NC} $1"; }

# Simple TOML parser using grep/awk
get_toml_val() {
    grep "^$1" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "'
}

# 1. SPIN_UP
spin_up() {
    CURRENT_STATE="SPIN_UP"
    log_info "Starting container..."
    
    local image
    image=$(get_toml_val "image")
    local name
    name=$(get_toml_val "container_name")
    local user
    user=$(get_toml_val "user")
    local pass
    pass=$(get_toml_val "password")
    local db
    db=$(get_toml_val "db_name")
    local port
    port=$(get_toml_val "port")

    docker run --rm --name "$name" \
        -e POSTGRES_USER="$user" -e POSTGRES_PASSWORD="$pass" -e POSTGRES_DB="$db" \
        -p "$port:5432" -d "$image" > /dev/null
    
    log_success "Container $name started on port $port"
}

# 2. HEALTH_CHECK
health_check() {
    CURRENT_STATE="HEALTH_CHECK"
    log_info "Waiting for DB to become ready..."
    
    local timeout
    timeout=$(get_toml_val "connection_timeout")
    local retries
    retries=$(get_toml_val "max_retries")
    local name
    name=$(get_toml_val "container_name")
    
    for i in $(seq 1 "$retries"); do
        if docker exec "$name" pg_isready -U postgres >/dev/null 2>&1; then
            log_success "Database is ready!"
            return 0
        fi
        log_warn "DB not ready, retrying... ($i/$retries)"
        sleep "$((timeout / retries))"
    done
    
    log_error "DB failed to initialize."
    return 1
}

# 3. TRANSACTION_TEST
transaction_test() {
    CURRENT_STATE="TRANSACTION_TEST"
    log_info "Running transaction tests..."
    
    local name
    name=$(get_toml_val "container_name")
    local db
    db=$(get_toml_val "db_name")
    
    # Simple table creation and insertion
    docker exec "$name" psql -U postgres -d "$db" -c "CREATE TABLE test_table (id INT, val TEXT);"
    docker exec "$name" psql -U postgres -d "$db" -c "INSERT INTO test_table VALUES (1, 'hello');"
    
    local result
    result=$(docker exec "$name" psql -U postgres -d "$db" -t -c "SELECT val FROM test_table WHERE id=1;")
    
    if [[ "$result" == *"hello"* ]]; then
        log_success "Transaction test passed!"
    else
        log_error "Transaction test failed. Result was: $result"
        return 1
    fi
}

# 4. TEARDOWN
teardown() {
    CURRENT_STATE="TEARDOWN"
    log_info "Cleaning up resources..."
    docker stop "$(get_toml_val "container_name")" > /dev/null 2>&1
    log_success "Resources cleaned."
}

# Trap for cleanup
trap teardown EXIT

# Main Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    spin_up || exit 1
    health_check || exit 1
    transaction_test || exit 1
    log_success "Integration Test Suite Passed Successfully."
fi
