{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.packages.cli;
in
{
  options.my.packages.cli.enable = lib.mkEnableOption "CLI packages";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      tmux
      jq
      curl
      wget
      neovim
      lsd
      fastfetch
      tldr
      p7zip
      xclip
      htop
      github-copilot-cli
    ];
  };
}
