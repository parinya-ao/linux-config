{ config, lib, ... }:

let
  cfg = config.my.programs.wayland;
in
{
  options.my.programs.wayland = {
    enable = lib.mkEnableOption "Wayland session variables";
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland,x11";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      NIXOS_OZONE_WL = "1";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "GNOME";
    };
  };
}
