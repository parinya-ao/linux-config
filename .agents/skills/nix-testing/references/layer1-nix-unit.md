# Layer 1 — Pure Nix Expression Unit Tests

Test library functions, overlays, and module assertions without building anything.

---

## Option A — `nix-unit` (recommended)

Standalone test runner for pure Nix expressions. Fast, focused, no build step.

### Add to flake.nix inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### Write tests (`tests/unit/lib-tests.nix`)

```nix
{ lib }:
{
  testConcat = {
    expr     = lib.concatStringsSep ", " [ "a" "b" "c" ];
    expected = "a, b, c";
  };

  strings.testTrim = {
    expr     = lib.strings.trim "  hello  ";
    expected = "hello";
  };

  testNestedGroup.testSub = {
    expr     = 1 + 1;
    expected = 2;
  };
}
```

### Run directly (no flake needed)

```bash
nix-unit --expr '{ lib, ... }: lib' --eval 'lib.trivial.id "hello"'
nix-unit ./tests/unit/lib-tests.nix --arg lib '(import <nixpkgs> {}).lib'
```

### Wire into flake.nix

```nix
# Option 1: flake.tests (system-agnostic)
flake.tests = import ./tests/unit/lib-tests.nix { lib = inputs.nixpkgs.lib; };

# Option 2: perSystem check via flake-parts
perSystem = { pkgs, lib, system, inputs', ... }: {
  checks.unit-tests = pkgs.runCommand "unit-tests" {
    nativeBuildInputs = [ inputs'.nix-unit.packages.default ];
    __noChroot = true;  # allow nix-unit to access flake inputs
  } ''
    nix-unit --flake ${self}#tests
    touch $out
  '';
};
```

### flake-parts integration

```nix
# flake.nix with flake-parts
{
  imports = [
    inputs.flake-parts.flakeModules.easyOverlay
  ];
  perSystem = { config, self', inputs', pkgs, system, ... }: {
    # Register tests so they appear in `nix flake show`
    checks = {
      unit = pkgs.runCommand "unit-tests" {
        nativeBuildInputs = [ inputs'.nix-unit.packages.default ];
      } ''
        nix-unit "--flake" "${self}#tests"
        touch $out
      '';
    };
  };
  flake.tests = import ./tests/unit/lib-tests.nix {
    lib = inputs.nixpkgs.lib;
  };
}
```

---

## Option B — `lib.debug.runTests` (no extra tooling)

Built into nixpkgs. No external dependencies.

### Write tests (`tests/run.nix`)

```nix
{ lib }:
let
  inherit (lib) runTests;
in
runTests {
  testConcat = {
    expr     = lib.concatStringsSep ", " [ "a" "b" "c" ];
    expected = "a, b, c";
  };
  testAdd = {
    expr     = 1 + 1;
    expected = 2;
  };
}
```

### Run

```bash
nix eval -f ./tests/run.nix
```

Output shows PASS/FAIL for each test.

---

## Common Pitfalls

| Problem | Fix |
|---------|-----|
| `nix-unit` can't find flake inputs | Use `--flake .#tests` instead of file path, or pass `--override-input` |
| Tests need `builtins.currentSystem` | Pass system as argument: `nix-unit --arg system builtins.currentSystem` |
| `runTests` output is huge | Pipe through `jq` or use `--option restrict-eval true` |
| Sandbox blocks `nix-unit` network | Use `__noChroot = true` in the derivation or `--option sandbox false` |
