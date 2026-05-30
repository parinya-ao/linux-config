# scaffold-nix-tests.sh — Example Output

Running `bash scaffold-nix-tests.sh mylib` produces:

```
tests/
├── unit/
│   └── default.nix     ← Layer 1 expression test stub
└── integration/
    └── default.nix     ← Layer 4 NixOS VM test stub
```

## tests/unit/default.nix (stub)

```nix
{ lib ? (import <nixpkgs> {}).lib }:
{
  testExample = {
    expr     = lib.concatStringsSep "-" [ "mylib" "test" ];
    expected = "mylib-test";
  };
}
```

Run immediately with `nix-unit ./tests/unit/default.nix`. Replace the example
with real assertions for your library functions.

## Wiring into flake.nix

The script prints the `checks` block to add to your `perSystem`:

```nix
checks = {
  unit-tests = pkgs.runCommand "unit-tests"
    { nativeBuildInputs = [ inputs'.nix-unit.packages.default ]; }
    ''
      export HOME="$(mktemp -d)"
      nix-unit --extra-experimental-features "nix-command flakes" \
        --flake ${self}#tests
      touch $out
    '';

  integration = import ./tests/integration/default.nix { inherit pkgs lib; };
};
```

After this, `nix flake check` runs both.
