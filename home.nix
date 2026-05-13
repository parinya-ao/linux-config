{ pkgs, ... }:

{
  home.username = "parinya";
  home.homeDirectory = "/home/parinya";
  home.stateVersion = "24.11";

  nixpkgs.config.allowUnfree = true;

  imports = [
    ./modules
  ];

  # --- Best Practice: Enable Suites ---
  my.suites = {
    base.enable = true;
    development.enable = true;
    ai.enable = true;
    desktop.enable = true;
  };

  programs.home-manager.enable = true;
}
