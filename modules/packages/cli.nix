{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    fd
    ripgrep
    fzf
    eza
    htop
    tmux
    jq
    curl
    wget
    neovim
    lsd
    fastfetch
    tldr
    p7zip
    unzip
    xclip
  ];
}
