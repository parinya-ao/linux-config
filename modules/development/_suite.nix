{ config, lib, ... }:

let
  cfg = config.my.development;
in
{
  options.my.development.enable = lib.mkEnableOption "Development environment (CLI tools, languages, editors)";

  config = lib.mkIf cfg.enable {
    my.development.cli-tools.enable = lib.mkDefault true;
    my.development.git.enable = lib.mkDefault true;
    my.development.languages.enable = lib.mkDefault true;
    my.development.editors.enable = lib.mkDefault true;
  };
}
