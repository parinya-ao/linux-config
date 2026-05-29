{ config, lib, ... }:

let
  cfg = config.my.productivity;
in
{
  options.my.productivity.enable = lib.mkEnableOption "Productivity tools (shells, documentation, GUI apps)";

  config = lib.mkIf cfg.enable {
    my.productivity.shells.enable = lib.mkDefault true;
    my.productivity.documentation.enable = lib.mkDefault true;
    my.productivity.gui-apps.enable = lib.mkDefault true;
  };
}
