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
    ./modules/programs/neovim.nix
    ./modules/packages/gui.nix
    ./modules/programs/cli-tools.nix
    ./modules/programs/gnome.nix
    ./modules/programs/zed.nix
  ];

  programs.home-manager.enable = true;

  # settings
  nix = {
    package = pkgs.nix;
    settings = {
      max-jobs = "auto";
      cores = 0;
      http-connections = 50;
      auto-optimise-store = true;
      substituters = [ "https://cache.nixos.org" ];
    };
  };
}
