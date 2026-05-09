# modules/packages/ai.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my.packages.ai;
in
{
  options.my.packages.ai = {
    enable = lib.mkEnableOption "AI Tools (Claude, Gemini)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.claude-code.packages.${pkgs.system}.default
      inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-fhs
    ];

    programs.gemini-cli = {
      enable = true;
      package = pkgs.gemini-cli;
      settings = {
        security.auth.selectedType = "oauth-personal";
        general.previewFeatures = true;
      };
    };
  };
}
