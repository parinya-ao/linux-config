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
  };

  # Entry point that processes inputs and defines system configurations.
  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Target system architecture.
      system = "x86_64-linux";
      # Package set instance for the defined system.
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Code formatter triggered by 'nix fmt'.
      formatter.${system} = pkgs.nixfmt-tree;

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
        ];
      };
    };
}
