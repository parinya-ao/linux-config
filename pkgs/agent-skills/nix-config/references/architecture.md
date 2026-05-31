# Architecture Deep Dive

## Module System

The project uses Nix's module system via Home Manager. Every module:

```nix
{ config, lib, pkgs, ... }:   # standard args
let
  cfg = config.my.something;  # shorthand
in
{
  options.my.something = { ... };  # declare options
  config = lib.mkIf cfg.enable { ... };  # apply config when enabled
}
```

### Import Chain

```
flake.nix → modules/default.nix → modules/{packages,programs,suites}.nix
                                  → modules/packages/*.nix
                                  → modules/programs/*.nix
```

### Option Patterns

| Pattern | When to Use |
|---|---|
| `lib.mkEnableOption "desc"` | Simple boolean toggle |
| `lib.mkOption { type = lib.types.str; default = "foo"; }` | String/other values |
| `lib.mkIf cond { ... }` | Conditional config |
| `lib.mkMerge [ ... ]` | Merge multiple configs |
| `lib.mkForce value` | Override from another module |

## Flake Inputs

Current inputs:

| Input | Source | Purpose |
|---|---|---|
| nixpkgs | github:NixOS/nixpkgs/nixos-unstable | Main package repo |
| home-manager | github:nix-community/home-manager | Home Manager itself |
| claude-code | github:theanhle0/claude-code-flake | Claude Code CLI |
| codex-cli | github:theanhle0/codex-cli-flake | Codex CLI |
| claude-desktop | github:theanhle0/claude-desktop-flake | Claude Desktop |
