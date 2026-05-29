{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.productivity.gui-apps;
in
{
  options.my.productivity.gui-apps.enable =
    lib.mkEnableOption "GUI applications (media, screenshot, document viewer)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      vlc
      flameshot
      kdePackages.okular
      gnome-tweaks
    ];
  };
}
