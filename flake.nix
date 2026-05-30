{
  # Description of the flake's purpose.
  description = "Home Manager configuration for user 'parinya' using Nix Flakes.";

  # External dependencies for this configuration.
  inputs = {
    # Main NixOS package repository (unstable branch for latest versions).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Tool for managing user environment and dotfiles.
    home-manager = {
      # Use master branch to match nixos-unstable nixpkgs.
      url = "github:nix-community/home-manager/master";
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
    { nixpkgs, home-manager, ... }@inputs:
    let
      # Target system architecture.
      system = "x86_64-linux";

      # ── Custom overlay: make agent-skills available as pkgs.agent-skills ──
      agentSkillsOverlay = final: prev: {
        agent-skills = final.callPackage ./pkgs/agent-skills { };
      };

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [ agentSkillsOverlay ];
      };
    in
    {
      # Expose agent-skills as a flake package so anyone can build and use it:
      #   nix build .#agent-skills
      #   nix build github:user/repo#agent-skills
      packages.${system}.agent-skills = pkgs.agent-skills;

      # Code formatter triggered by 'nix fmt'.
      formatter.${pkgs.stdenv.hostPlatform.system} = pkgs.nixfmt-tree;

      # Home Manager configuration for user 'parinya'.
      homeConfigurations."parinya" = home-manager.lib.homeManagerConfiguration {
        # Pass the package set into the configuration modules.
        inherit pkgs;

        # Inject additional variables (like flake inputs) into all sub-modules.
        # This is required for modules like home.nix to access 'inputs.claude-code'.
        extraSpecialArgs = { inherit inputs; };

        # List of configuration modules to apply.
        modules = [
          ./home.nix

          (
            { pkgs, ... }:
            {
              programs.fish.shellAliases = {
                uv = "env LD_LIBRARY_PATH=/usr/lib64:${
                  pkgs.lib.makeLibraryPath (
                    with pkgs;
                    [
                      pkgs.stdenv.cc.cc.lib
                      zlib
                      zstd
                      glib
                    ]
                  )
                } uv";
              };
            }
          )
        ];
      };
    };
}
