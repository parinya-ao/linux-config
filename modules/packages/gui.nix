{ pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    vlc
    flameshot
    kdePackages.okular
    gnome-tweaks

    noto-fonts
    noto-fonts-cjk-sans
    inter
    intel-one-mono
    ibm-plex
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];
}
