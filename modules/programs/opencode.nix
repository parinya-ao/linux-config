{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.opencode;
in
{
  options.my.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode — AI coding assistant (installed via bun)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bun
    ];
  };
}
