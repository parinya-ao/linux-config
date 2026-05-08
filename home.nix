{ pkgs, ... }:

{
  home.username = "parinya";
  home.homeDirectory = "/home/parinya";
  home.stateVersion = "24.11";

  imports = [
    ./modules/packages/cli.nix
    ./modules/packages/dev.nix
    ./modules/packages/docs.nix
    ./modules/programs/git.nix
    ./modules/programs/bash.nix
    ./modules/programs/fish.nix
    ./modules/packages/gui.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/gnome.nix
    ./modules/programs/zed.nix
  ];

  programs.home-manager.enable = true;
<<<<<<< Updated upstream

  nix = {
	package = pkgs.nix;
    settings = {
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 28d";
    };
  };
=======
>>>>>>> Stashed changes
}
