{ ... }:

{
  imports = [
    ./suites.nix
    ./packages/ai.nix
    ./packages/cli.nix
    ./packages/dev.nix
    ./packages/docs.nix
    ./packages/gui.nix
    ./programs/agent-skills.nix
    ./programs/agentmemory.nix
    ./programs/codegraph.nix
    ./programs/bash.nix
    ./programs/cli-tools.nix
    ./programs/fish.nix
    ./programs/git.nix
    ./programs/gnome.nix
    ./programs/neovim.nix
    ./programs/react-doctor.nix
    ./programs/opencode.nix
    ./programs/rtk.nix
    ./packages/font.nix
  ];
}
