{ pkgs, inputs, ... }:

{
  # Install standalone CLI packages that do not have dedicated Home Manager modules yet.
  home.packages = [
    # Install Claude Code CLI from the flake input
    inputs.claude-code.packages.${pkgs.system}.default
  ];

  # Configure eza (a modern, maintained replacement for ls)
  programs.eza = {
    enable = true;
    # Automatically create aliases like 'ls' and 'll' for Fish shell
    enableFishIntegration = true;
    # Enable icons in terminal output
    icons = "auto";
  };

  # Configure bat (a cat clone with syntax highlighting and Git integration)
  programs.bat = {
    enable = true;
    config = {
      # Set the default syntax highlighting theme
      theme = "TwoDark";
    };
  };
  
  # Configure direnv (unclutter your .profile and manage environment variables)
  programs.direnv = {
    enable = true;
    # Enable fast, persistent use_nix and use_flake support
    nix-direnv.enable = true;
  };

  # Configure gemini-cli (Google's Gemini CLI client)
  programs.gemini-cli = {
    enable = true;
    package = pkgs.gemini-cli;

    settings = {
      # Use personal OAuth for authentication
      security.auth.selectedType = "oauth-personal";
      # Opt-in to early preview features
      general.previewFeatures = true;
    };
  };
}
