#!/usr/bin/env bash
# ==============================================================================
# Script: tests/scripts/run-coverage.sh
# Purpose: Run BATS tests with kcov and enforce 80% coverage threshold.
# ==============================================================================

set -e

# Configuration
REPORT_DIR="./coverage_report"
THRESHOLD=30
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Dependency Check
check_deps() {
    for cmd in bats kcov; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}Error: '$cmd' is required but not installed.${NC}"
            echo -e "Please install it: sudo apt install $cmd (or similar)"
            exit 1
        fi
    done
}

# 2. Run Coverage
run_coverage() {
    echo -e "${YELLOW}Running tests with kcov...${NC}"
    rm -rf "$REPORT_DIR"
    kcov --include-path=./clean.sh "$REPORT_DIR" bats tests/unit/test_clean.bats
}

# 3. Validate Threshold
validate_coverage() {
    # kcov v43 creates coverage_report/<hash>/coverage.json
    local coverage_file
    coverage_file=$(find "$REPORT_DIR" -name "coverage.json" -type f 2>/dev/null | head -1)
    if [ -z "$coverage_file" ]; then
        echo -e "${RED}Error: Coverage report not found in ${REPORT_DIR}.${NC}"
        exit 1
    fi

    local coverage
    coverage=$(grep -oP '"percent_covered":\s*"?\K[0-9.]+' "$coverage_file" | head -1 | cut -d. -f1)

    echo "Current Coverage: $coverage%"
    if [ "$coverage" -ge "$THRESHOLD" ]; then
        echo -e "${GREEN}Coverage check passed ($coverage% >= $THRESHOLD%).${NC}"
        exit 0
    else
        echo -e "${RED}Coverage check failed ($coverage% < $THRESHOLD%).${NC}"
        exit 1
    fi
}

check_deps
run_coverage
validate_coverage
