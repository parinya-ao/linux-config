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
    enable = lib.mkEnableOption "AI Tools (Claude, Antigravity)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs
    ];
  };
}
