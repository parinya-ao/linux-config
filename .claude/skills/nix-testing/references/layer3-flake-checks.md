# Layer 3 — Flake Checks (CI Entry Point)

`nix flake check` is your single CI command. It runs every derivation listed
under `checks.${system}.*`. Wire Layers 1, 2, and any linters here.

## Full flake-parts template

```nix
# flake.nix
{
  description = "My project — full test coverage";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-unit.url    = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url   = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-unit.modules.flake.default
        inputs.git-hooks.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      # ── System-agnostic expression tests ──────────────────────────────
      flake.tests = import ./tests/unit/lib-tests.nix {
        inherit (inputs.nixpkgs.lib) lib;
      };

      perSystem = { pkgs, lib, system, inputs', config, self', ... }: {

        # ── Packages ────────────────────────────────────────────────────
        packages.mypkg   = pkgs.callPackage ./pkgs/mypkg/default.nix { };
        packages.default = config.packages.mypkg;

        # ── Per-system nix-unit tests ────────────────────────────────────
        nix-unit.tests.testPkgsSystem = {
          expr     = pkgs.system;
          expected = system;
        };

        # ── Pre-commit hooks ─────────────────────────────────────────────
        pre-commit.settings.hooks = {
          nixfmt-rfc-style.enable = true;
          statix.enable           = true;   # anti-pattern linter
          deadnix.enable          = true;   # unused bindings
        };

        # ── checks = what `nix flake check` runs ──────────────────────
        checks = {
          # Layer 2: build + checkPhase
          mypkg-build = config.packages.mypkg;

          # Layer 2: passthru smoke test
          mypkg-smoke = config.packages.mypkg.passthru.tests.run-binary;

          # Linting: nixfmt + statix
          formatting = pkgs.runCommand "nix-fmt-check"
            { nativeBuildInputs = [ pkgs.nixfmt-rfc-style pkgs.statix ]; }
            ''
              nixfmt --check ${./flake.nix}
              statix check ${./.}
              touch $out
            '';

          # Pre-commit hook check (optional — useful in CI)
          pre-commit = config.pre-commit.check;
        };

        # devShell installs pre-commit hooks on `nix develop`
        devShells.default = pkgs.mkShell {
          inherit (config.pre-commit.devShell) shellHook;
          packages = [ pkgs.nixfmt-rfc-style pkgs.statix pkgs.deadnix ];
        };
      };
    };
}
```

## Running checks

```bash
# Run ALL checks (this is your CI command)
nix flake check

# Verbose — show test output even when tests pass
nix flake check -L

# Single system (faster during development)
nix flake check --system x86_64-linux

# One specific check
nix build .#checks.x86_64-linux.mypkg-smoke -L

# List all available checks
nix flake show 2>&1 | grep checks
```

## GitHub Actions CI

```yaml
# .github/workflows/nix-check.yml
name: Nix Flake Check

on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@main

      # Binary cache — avoids rebuilding unchanged derivations
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Run flake checks
        run: nix flake check --system x86_64-linux -L

  # Separate job for macOS if you need Darwin support
  check-darwin:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - run: nix flake check --system aarch64-darwin -L
```

## Pre-commit hooks (git-hooks.nix)

With the `flake-parts` template above, running `nix develop` auto-installs
pre-commit hooks. They run on every `git commit`:

```bash
nix develop   # installs hooks
git commit    # triggers: nixfmt, statix, deadnix
```

To run hooks manually without committing:
```bash
nix develop -c pre-commit run --all-files
```

## Tips

- **Always commit `flake.lock`.** CI must use the exact same nixpkgs you
  tested with locally. Never run `nix flake update` in CI.
- **Separate fast checks from slow ones.** Run Layers 1+2 on every PR.
  Gate Layer 4 VM tests to a nightly job.
- **Use `pkgs.runCommand` for script-based checks.** It runs in the Nix
  sandbox, which means it is reproducible. Always end with `touch $out`.
- **`nix flake check` evaluates all systems** unless you pass `--system`.
  If you only have an x86 machine, add `--system x86_64-linux` everywhere.
