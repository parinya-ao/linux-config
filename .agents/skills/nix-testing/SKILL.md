---
name: nix-testing
description: >
  Expert guidance for testing Nix packages and flakes. Use this skill whenever
  the user mentions: nix-unit, checkPhase, installCheckPhase, doCheck,
  nix flake check, passthru.tests, nixosTest, runNixOSTest, stdenv tests,
  flake checks, NixOS integration tests, nix expression tests, nix CI testing,
  or testing any Nix derivation/package/overlay. Also trigger when the user
  wants to validate a flake.nix, test a Nix library function, or set up Nix
  test automation. Don't wait for the user to say "nix test" explicitly —
  if they're working on a Nix project and ask about tests, use this skill.
when_to_use: >
  Trigger phrases: "test my nix package", "add tests to flake", "nix-unit setup",
  "checkPhase not running", "nix flake check fails", "how to test nixos module",
  "passthru tests nix", "nix CI testing", "unit test nix expression",
  "nix build check", "stdenv doCheck", "nixos vm test".
argument-hint: "[layer] — one of: unit | package | flake | nixos | all | ci"
allowed-tools: Bash Read Write
---

# Nix Testing Skill

You are a Nix testing expert. Apply the **4-Layer Testing Model** below for all
Nix testing tasks. Always state which layer applies, give copy-paste-ready code,
and explain *why* each pattern is used — not just what to write.

## Detect project context

```bash
[ -f flake.nix ] && echo "--- flake.nix (first 60 lines) ---" && head -60 flake.nix || echo "(no flake.nix in cwd)"
[ -d tests ] && echo "--- tests/ ---" && find tests -name "*.nix" 2>/dev/null | head -15 || true
[ -f default.nix ] && echo "--- default.nix (first 30 lines) ---" && head -30 default.nix || true
```

***

## The 4-Layer Testing Model

```
Layer 1  Expression Tests    nix-unit / lib.debug.runTests   Pure Nix functions & overlays
Layer 2  Package Build Tests checkPhase / installCheckPhase  stdenv derivations
Layer 3  Flake Checks        checks.${system}.*              CI entry point (nix flake check)
Layer 4  NixOS Integration   pkgs.testers.runNixOSTest       Full VM / systemd service tests
```

Pick the right layer first — then see the reference file for that layer.

| I want to…                                 | Layer |
|--------------------------------------------|-------|
| Test a lib function, overlay, or module    | 1     |
| Verify a package compiles + test suite runs | 2    |
| Wire everything so `nix flake check` works  | 3    |
| Test a running service / OS config          | 4    |
| Set up GitHub Actions CI                    | 3 + CI section in [references/layer3-flake-checks.md](references/layer3-flake-checks.md) |

***

## Quick Start (30 seconds)

```bash
# Write and run a pure Nix expression test — no flake needed
cat > tests.nix << 'NIX'
{ lib ? (import <nixpkgs> {}).lib }:
{
  testConcat = {
    expr     = lib.concatStringsSep ", " [ "a" "b" "c" ];
    expected = "a, b, c";
  };
}
NIX
nix-unit ./tests.nix
```

For anything beyond a quick smoke test, read the layer-specific reference file.

***

## Layer References

Each reference file has copy-paste templates, annotated examples, and common
pitfalls. Load only what you need.

- **[references/layer1-nix-unit.md](references/layer1-nix-unit.md)**
  Pure Nix expression tests with `nix-unit`, `lib.debug.runTests`, flake
  integration, and `flake-parts` wiring.

- **[references/layer2-package-tests.md](references/layer2-package-tests.md)**
  `checkPhase`, `installCheckPhase`, `doCheck`, `passthru.tests`, and
  `pkgs.testers.*` helpers.

- **[references/layer3-flake-checks.md](references/layer3-flake-checks.md)**
  Full `flake-parts` `checks` template, `nix flake check` usage, GitHub Actions
  CI workflow, and `git-hooks.nix` pre-commit setup.

- **[references/layer4-nixos-tests.md](references/layer4-nixos-tests.md)**
  `pkgs.testers.runNixOSTest` / `nixosTest`, multi-node VMs, Python test script
  patterns, and interactive debugging.

***

## Common Mistakes → Fixes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `doCheck = true` but nothing runs | Empty `checkPhase` | Add an explicit `checkPhase`; some build systems also need `checkTarget` |
| `nix-unit` sandbox fails to fetch inputs | Sandbox blocks network | Pass all inputs via `--override-input` (see layer1 ref) |
| `pkgs.runCommand` check outputs nothing | Missing `$out` | Always end build script with `touch $out` |
| Tests pass locally, fail in CI | Unpinned nixpkgs | Commit `flake.lock`; never `--update-input` in CI |
| VM tests time out in CI | Too many VM tests per job | Run Layers 1+2 on every PR; gate VM tests to nightly |
| `checkPhase` skipped in `nix develop` | Shell disables doCheck | Run `eval "$checkPhase"` manually, or use `nix develop --check` |
| `nix flake check` hangs | Evaluating all systems | Pass `--system x86_64-linux` to limit scope |

***

## Scaffolding a New Test Suite

Use the bundled scaffold script to bootstrap a project:

```bash
bash ${AGENT_SKILL_DIR}/scripts/scaffold-nix-tests.sh [project-name]
```

The script creates `tests/unit/default.nix`, `tests/integration/`, and wires
`checks` into an existing `flake.nix` if present. See
[examples/scaffold-output.md](examples/scaffold-output.md) for what it produces.
