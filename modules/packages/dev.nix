{ pkgs, ... }:

{
  home.packages = with pkgs; [
    temurin-bin
    maven
    gradle
    # gcc
    clang
    go
    nodejs
    python3
    uv
    bun
    docker-compose
    distrobox
  ];
}
