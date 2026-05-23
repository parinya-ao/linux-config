#!/usr/bin/env bash
# ==============================================================================
# Utility: parse_config.sh
# Purpose: Extract values from config.toml using POSIX-compliant tools.
# Usage: source ./scripts/parse_config.sh
#        VAL=$(get_toml_val "section" "key")
# ==============================================================================

# get_toml_val accepts section and key as arguments
get_toml_val() {
    local section="$1"
    local key="$2"
    local config_file="./config.toml"

    # Use sed to find the section, then search for the key, 
    # then strip whitespace and quotes from the resulting value.
    # Logic:
    # 1. sed -n "/\[$section\]/,/\[.*\]/p": extract lines between section headers
    # 2. grep "^$key\s*=": find the specific key assignment
    # 3. cut -d'=' -f2-: get the value part
    # 4. tr -d ' "': strip quotes and remaining spaces
    
    sed -n "/\[$section\]/,/\[.*\]/p" "$config_file" | \
    grep "^$key\s*=" | \
    cut -d'=' -f2- | \
    tr -d ' "' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
