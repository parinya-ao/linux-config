{ pkgs, ... }:

{
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
  ];
}
