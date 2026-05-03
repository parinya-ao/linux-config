{ pkgs, ... }:

{
  home.packages = with pkgs; [
    typst
    d2
    pandoc
  ];
}
