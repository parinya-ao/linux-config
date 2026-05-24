{
  # Description of the flake's purpose.
  description = "Home Manager configuration for user 'parinya' using Nix Flakes.";

  # External dependencies for this configuration.
  inputs = {
    # Main NixOS package repository (unstable branch for latest versions).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Tool for managing user environment and dotfiles.
    home-manager = {
      url = "github:nix-community/home-manager";
      # Ensure home-manager uses the same nixpkgs version to save space.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Third-party flake providing the Claude Code CLI.
    claude-code.url = "github:sadjow/claude-code-nix";

    # flake claude desktop
    claude-desktop.url = "github:aaddrick/claude-desktop-debian";

    # Third-party flake providing the Codex CLI.
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  # Entry point that processes inputs and defines system configurations.
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      claude-code,
      claude-desktop,
      codex-cli-nix,
      ...
    }@inputs:
    let
      # Target system architecture.
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      stdenv = pkgs.stdenv;
    in
    {
      # Code formatter triggered by 'nix fmt'.
      formatter.${stdenv.hostPlatform.system} = pkgs.nixfmt-tree;

      # Home Manager configuration for user 'parinya'.
      homeConfigurations."parinya" = home-manager.lib.homeManagerConfiguration {
        # Pass the package set into the configuration modules.
        pkgs = pkgs;

        # Inject additional variables (like flake inputs) into all sub-modules.
        # This is required for modules like home.nix to access 'inputs.claude-code'.
        extraSpecialArgs = { inherit inputs; };

        # List of configuration modules to apply.
        modules = [
          ./home.nix
        ];
      };
    };
}
