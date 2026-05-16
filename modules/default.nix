{ ... }:

{
  imports = [
    ./suites.nix
    ./packages/ai.nix
    ./packages/audit.nix
    ./packages/cli.nix
    ./packages/dev.nix
    ./packages/docs.nix
    ./packages/gui.nix
    ./programs/bash.nix
    ./programs/cli-tools.nix
    ./programs/fish.nix
    ./programs/git.nix
    ./programs/gnome.nix
    ./programs/neovim.nix
    ./programs/wayland.nix
  ];
}
