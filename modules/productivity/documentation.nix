{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.productivity.documentation;
in
{
  options.my.productivity.documentation.enable =
    lib.mkEnableOption "Documentation tools (typst, d2, pandoc)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      typst
      d2
      pandoc
    ];
  };
}
