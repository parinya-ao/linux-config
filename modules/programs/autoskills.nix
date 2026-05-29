{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.autoskills;
in
{
  options.my.programs.autoskills = {
    enable = lib.mkEnableOption "autoskills — auto-install AI agent skills for your project stack";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bun
    ];
  };
}
