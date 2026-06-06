{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my.ai.tools;
in
{
  options.my.ai.tools.enable = lib.mkEnableOption "AI CLI tools (Claude, Codex)";

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs
      inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.bash
    ];
  };
}
