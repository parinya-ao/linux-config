{ config, lib, ... }:

let
  cfg = config.my.ai;
in
{
  options.my.ai.enable = lib.mkEnableOption "AI-assisted development (assistants, coding helpers)";

  config = lib.mkIf cfg.enable {
    my.ai.tools.enable = lib.mkDefault true;
    my.ai.coding-helpers.enable = lib.mkDefault true;
  };
}
