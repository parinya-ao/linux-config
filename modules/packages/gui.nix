{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.packages.gui;
in
{
  options.my.packages.gui.enable = lib.mkEnableOption "GUI packages";

  config = lib.mkIf cfg.enable {
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      vlc
      flameshot
      kdePackages.okular
      gnome-tweaks

      noto-fonts
      noto-fonts-cjk-sans
      inter
      intel-one-mono
      ibm-plex
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
  };
}
