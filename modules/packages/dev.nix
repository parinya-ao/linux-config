{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
