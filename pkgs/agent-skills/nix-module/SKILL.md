# Nix Module & Home Manager Skill
Specialist in declarative environment management.

## Guidelines
- Follow the modular architecture: separate logic into logical files.
- Use `lib.mkIf` and `lib.mkOption` for clean interfaces.
- Prefer `writeShellScriptBin` for custom CLI tools.
- Maintain idempotent bootstrap scripts in `distro/`.
- Use `flake.nix` for managing inputs and outputs reproducible.
