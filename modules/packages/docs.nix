{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.packages.docs;
in
{
  options.my.packages.docs.enable = lib.mkEnableOption "Documentation tools";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      typst
      d2
      pandoc
    ];
  };
}
