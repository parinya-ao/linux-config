#!/usr/bin/env bash

# Static Analysis & Linting Script
# This script scans Bash (.sh) and Fish (.fish) files for syntax errors and common pitfalls.
# It is designed for both local development and CI/CD pipelines.

# --- Configuration ---
# Set colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize failure flag
EXIT_CODE=0

# --- Helper Functions ---
print_header() {
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# --- Tool Checks ---
echo -e "${YELLOW}Initializing Linting Engine...${NC}"

# Find files first to decide if tools are mandatory
SH_FILES=$(find . -type f -name "*.sh" -not -path "*/.git/*")
FISH_FILES=$(find . -type f -name "*.fish" -not -path "*/.git/*")

# Check for shellcheck
if [ -n "$SH_FILES" ]; then
    if ! command -v shellcheck &> /dev/null; then
        echo -e "${RED}Error: 'shellcheck' not found but .sh files exist.${NC}"
        EXIT_CODE=1
        CHECK_SH=false
    else
        CHECK_SH=true
    fi
else
    CHECK_SH=false
fi

# Check for fish
if [ -n "$FISH_FILES" ]; then
    if ! command -v fish &> /dev/null; then
        echo -e "${RED}Error: 'fish' not found but .fish files exist.${NC}"
        EXIT_CODE=1
        CHECK_FISH=false
    else
        CHECK_FISH=true
    fi
else
    CHECK_FISH=false
fi

# --- Scan Bash Scripts ---
if [ "$CHECK_SH" = true ]; then
    print_header "Scanning Bash Scripts (*.sh)"
    
    # Use find with -print0 to handle filenames with spaces
    while IFS= read -r -d '' file; do
        echo -n "Checking $file... "
        # Run shellcheck and capture output
        lint_output=$(shellcheck "$file" 2>&1)
        status=$?
        
        if [ $status -eq 0 ]; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}ERROR${NC}"
            echo -e "${RED}--------------------------------------------------${NC}"
            echo "$lint_output"
            echo -e "${RED}--------------------------------------------------${NC}"
            EXIT_CODE=1
        fi
    done < <(find . -type f -name "*.sh" -not -path "*/.git/*" -print0)
fi

# --- Scan Fish Scripts ---
if [ "$CHECK_FISH" = true ]; then
    print_header "Scanning Fish Scripts (*.fish)"
    
    while IFS= read -r -d '' file; do
        echo -n "Checking $file... "
        # Run fish --no-execute and capture output
        # fish --no-execute doesn't print much on success, but errors go to stderr
        lint_output=$(fish --no-execute "$file" 2>&1)
        status=$?
        
        if [ $status -eq 0 ]; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}ERROR${NC}"
            echo -e "${RED}--------------------------------------------------${NC}"
            echo -e "${RED}$lint_output${NC}"
            echo -e "${RED}--------------------------------------------------${NC}"
            EXIT_CODE=1
        fi
    done < <(find . -type f -name "*.fish" -not -path "*/.git/*" -print0)
fi

# --- Summary ---
echo ""
print_header "Linting Summary"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All scripts passed validation.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some scripts failed validation or tools were missing.${NC}"
    exit 1
fi
