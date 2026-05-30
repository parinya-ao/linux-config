{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.development.languages;
in
{
  options.my.development.languages.enable = lib.mkEnableOption "Language runtimes & SDKs";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      temurin-bin
      maven
      gradle
      clang
      go
      nodejs
      python3
      uv
      bun
      shellcheck
      docker-compose
      distrobox
    ];
  };
}
