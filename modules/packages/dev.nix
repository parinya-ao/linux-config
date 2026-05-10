{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.packages.dev;
in
{
  options.my.packages.dev.enable = lib.mkEnableOption "Development packages";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      temurin-bin
      maven
      gradle
      # gcc
      clang
      gdb
      clang-tools
      go
      nodejs
      python3
      uv
      bun
      docker-compose
      distrobox
    ];
  };
}
