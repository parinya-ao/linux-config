{ ... }:

{
  home = {
    username = "parinya";
    homeDirectory = "/home/parinya";
    stateVersion = "24.11";
    enableNixpkgsReleaseCheck = false;
  };

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

  # Disable noisy news notifications
}
