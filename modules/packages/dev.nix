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
      (lib.hiPrio gcc)
      # clang
      go
      nodejs
      python3
      uv
      bun
      shellcheck
      docker-compose
      distrobox
      cmake
      freetype
      fontconfig
      xorg.libxcb
      libxkbcommon
      scdoc
      gzip
      cargo
      rustc
      gnumake
      pkg-config
      openssl.dev
    ];
  };
}
