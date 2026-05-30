#!/usr/bin/env bash
# ==============================================================================
# Script: tests/scripts/run-coverage.sh
# Purpose: Run BATS unit tests.
# ==============================================================================

set -e

echo "Running unit tests..."
bats tests/unit/test_clean.bats
