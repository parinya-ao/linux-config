{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.react-doctor;
in
{
  options.my.programs.react-doctor = {
    enable = lib.mkEnableOption "React Doctor — scans React codebases for issues";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      bun
    ];
  };
}
