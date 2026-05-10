{ pkgs, ... }:

{
  home.username = "parinya";
  home.homeDirectory = "/home/parinya";
  home.stateVersion = "24.11";

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
