#!/usr/bin/env bats

# ==============================================================================
# Unit Test: tests/unit/test_clean.bats
# Purpose: Test clean.sh logic using mocking
# ==============================================================================

# Setup: runs before each test
setup() {
    # สร้าง directory ชั่วคราวสำหรับ mock bin
    export MOCK_BIN_DIR="${BATS_TMPDIR}/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"
    export PATH="${MOCK_BIN_DIR}:${PATH}"
    
    # Source the clean script
    # โดยธรรมชาติ Bash จะตรวจสอบ if [[ "${BASH_SOURCE[0]}" == "${0}" ]] 
    # ดังนั้นการ source เข้ามาจะไม่รัน main() โดยอัตโนมัติ
    source "${BATS_TEST_DIRNAME}/../../clean.sh"
}

# Teardown: runs after each test
teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

# --- Case 1: Happy Path - verify_dependencies ---
@test "verify_dependencies: pass when nix commands exist" {
    # สร้าง mock command
    touch "${MOCK_BIN_DIR}/nix-env"
    chmod +x "${MOCK_BIN_DIR}/nix-env"
    touch "${MOCK_BIN_DIR}/nix-store"
    chmod +x "${MOCK_BIN_DIR}/nix-store"
    
    run verify_dependencies
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checking for required Nix commands"* ]]
}

# --- Case 2: Sad Path - verify_dependencies (missing binary) ---
@test "verify_dependencies: fail when nix-store is missing" {
    touch "${MOCK_BIN_DIR}/nix-env"
    chmod +x "${MOCK_BIN_DIR}/nix-env"
    # ไม่สร้าง nix-store
    
    run verify_dependencies
    
    [ "$status" -eq 1 ]
    # ตรวจสอบว่ามี error message พ่นออกมา
    [[ "$output" == *"not found"* ]]
}

# --- Case 3: Mock Output Parsing - run_garbage_collection ---
@test "run_garbage_collection: parse freed bytes correctly" {
    # สร้าง mock command nix-store
    cat << 'EOF' > "${MOCK_BIN_DIR}/nix-store"
#!/usr/bin/env bash
echo "123456 bytes freed"
exit 0
EOF
    chmod +x "${MOCK_BIN_DIR}/nix-store"
    
    # รันฟังก์ชัน
    run run_garbage_collection
    
    [ "$status" -eq 0 ]
    # ตรวจสอบ log ที่เกิดขึ้นภายในฟังก์ชัน
    # ตรวจสอบว่าข้อความที่ log success มีตัวเลข 123456
    [[ "$output" == *"Freed: 123456 bytes"* ]]
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
