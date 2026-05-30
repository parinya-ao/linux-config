#!/usr/bin/env bash
# scaffold-nix-tests.sh — Bootstrap Nix test suite for an existing project
set -euo pipefail

PROJECT_NAME="${1:-$(basename "$(pwd)")}"

echo "==> Scaffolding Nix test suite for: $PROJECT_NAME"

# Create test directories
mkdir -p tests/unit tests/integration

# Write layer 1 unit test template
if [ ! -f tests/unit/default.nix ]; then
  cat > tests/unit/default.nix << 'NIX'
{ lib }:
{
  testHelloWorld = {
    expr     = lib.strings.concatStringsSep " " [ "hello" "world" ];
    expected = "hello world";
  };
}
NIX
  echo "  [created] tests/unit/default.nix"
else
  echo "  [skip]    tests/unit/default.nix (exists)"
fi

# Write layer 4 integration test template
if [ ! -f tests/integration/default.nix ]; then
  cat > tests/integration/default.nix << 'NIX'
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "smoke-test";
  nodes.machine = { config, pkgs, ... }: {
    # Add your service config here
  };
  testScript = ''
    machine.start()
    machine.succeed("true")  # replace with real assertions
  '';
}
NIX
  echo "  [created] tests/integration/default.nix"
else
  echo "  [skip]    tests/integration/default.nix (exists)"
fi

# Wire checks into flake.nix if present
if [ -f flake.nix ]; then
  if grep -q "checks" flake.nix 2>/dev/null; then
    echo "  [skip]    flake.nix (already has checks)"
  else
    echo ""
    echo "==> NOTE: Add these to your flake.nix manually:"
    echo ""
    echo '  perSystem = { pkgs, lib, system, inputs', ... }: {'
    echo '    checks = {'
    echo '      unit = pkgs.callPackage ./tests/unit { };'
    echo '      integration = pkgs.callPackage ./tests/integration { };'
    echo '    };'
    echo '  };'
    echo ""
  fi
fi

echo "==> Done. Run tests with:"
echo "  nix flake check -L"
