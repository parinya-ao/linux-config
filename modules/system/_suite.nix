{ config, lib, ... }:

let
  cfg = config.my.system;
in
{
  options.my.system.enable = lib.mkEnableOption "System-level configuration (fonts, display, desktop)";

  config = lib.mkIf cfg.enable {
    my.system.fonts.enable = lib.mkDefault true;
    my.system.gnome.enable = lib.mkDefault true;
  };
}
