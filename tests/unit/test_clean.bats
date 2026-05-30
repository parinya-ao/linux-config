#!/usr/bin/env bats

# ==============================================================================
# Unit Test: tests/unit/test_clean.bats
# Purpose: Test clean.sh logic using mocking
# ==============================================================================

# Setup: runs before each test
setup() {
    # Create temporary directory for mock binaries
    export MOCK_BIN_DIR="${BATS_TMPDIR}/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"
    export PATH="${MOCK_BIN_DIR}:${PATH}"
    
    # Mock gum: handles spin, style, and format subcommands
    cat << 'GUM_EOF' > "${MOCK_BIN_DIR}/gum"
#!/usr/bin/env bash
cmd="$1"
shift
case "$cmd" in
    spin)
        # gum spin --spinner <type> --title "<title>" -- <command> [args...]
        args=(); found=false
        for arg in "$@"; do
            if [[ "$arg" == "--" ]]; then found=true; continue; fi
            $found && args+=("$arg")
        done
        exec "${args[@]}"
        ;;
    style|format)
        # gum style --foreground <color> "text" → echo text
        for arg in "$@"; do
            [[ "$arg" != -* ]] && echo "$arg"
        done
        ;;
    *)
        exec "$cmd" "$@"
        ;;
esac
GUM_EOF
    chmod +x "${MOCK_BIN_DIR}/gum"
    
    # Source the clean script
    source "${BATS_TEST_DIRNAME}/../../clean.sh"
}

# Teardown: runs after each test
teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

# --- Case 1: Happy Path - verify_dependencies ---
@test "verify_dependencies: pass when nix commands exist" {
    # Create mock commands
    touch "${MOCK_BIN_DIR}/nix-env"
    chmod +x "${MOCK_BIN_DIR}/nix-env"
    touch "${MOCK_BIN_DIR}/nix-store"
    chmod +x "${MOCK_BIN_DIR}/nix-store"
    
    run verify_dependencies
    [ "$status" -eq 0 ]
    # Verify the log file contains the expected debug message
    grep -q "Checking for required Nix commands" /tmp/nix_system_cleanup.log
}

# --- Case 2: Sad Path - verify_dependencies (missing binary) ---
@test "verify_dependencies: fail when nix-store is missing" {
    touch "${MOCK_BIN_DIR}/nix-env"
    chmod +x "${MOCK_BIN_DIR}/nix-env"
    # Do not create nix-store
    
    run verify_dependencies
    
    [ "$status" -eq 1 ]
    # Verify the log file contains the error message
    grep -q "not found" /tmp/nix_system_cleanup.log
}

# --- Case 3: Mock Output Parsing - run_garbage_collection ---
@test "run_garbage_collection: parse freed bytes correctly" {
    # Create mock nix-store
    cat << 'EOF' > "${MOCK_BIN_DIR}/nix-store"
#!/usr/bin/env bash
echo "123456 bytes freed"
exit 0
EOF
    chmod +x "${MOCK_BIN_DIR}/nix-store"
    
    run run_garbage_collection
    
    [ "$status" -eq 0 ]
    # Verify freed bytes parsed correctly in the log file
    grep -q "Freed: 123456 bytes" /tmp/nix_system_cleanup.log
    # Verify the GC output was captured in the log
    grep -q "123456 bytes freed" /tmp/nix_system_cleanup.log
}

# --- Case 4: State Transition & Variables ---
@test "State check sequence" {
    # Mocking environment
    touch "${MOCK_BIN_DIR}/nix-env" && chmod +x "${MOCK_BIN_DIR}/nix-env"
    touch "${MOCK_BIN_DIR}/nix-store" && chmod +x "${MOCK_BIN_DIR}/nix-store"

    # รันทีละฟังก์ชันแล้วเช็ก state
    verify_dependencies
    [ "$CURRENT_STATE" = "VERIFY_DEPENDENCIES" ]
    
    # Mock nix-env --delete-generations
    echo "#!/usr/bin/env bash" > "${MOCK_BIN_DIR}/nix-env"
    chmod +x "${MOCK_BIN_DIR}/nix-env"
    
    remove_old_generations
    [ "$CURRENT_STATE" = "REMOVE_OLD_GENERATIONS" ]
}
