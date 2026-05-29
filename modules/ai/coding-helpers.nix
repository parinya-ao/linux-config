{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.ai.coding-helpers;
in
{
  options.my.ai.coding-helpers.enable =
    lib.mkEnableOption "AI coding assistants (OpenCode, React Doctor, AutoSkills)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bun
    ];
  };
}
