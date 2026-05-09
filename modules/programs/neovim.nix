{ pkgs, ... }:

let
  kickstart = pkgs.fetchFromGitHub {
    owner = "nvim-lua";
    repo = "kickstart.nvim";
    rev = "cfdc17be3ae1607d4427332de0b29d556f9dda13";
    sha256 = "14bb9x2scbxzvaswcq7lnl868lirn3rjyr8y98rs20di9vhzki10";
  };
in
{
  # This deploys the kickstart.nvim config to ~/.config/nvim
  # Neovim will handle plugin installation (lazy.nvim) on its first run.
  xdg.configFile."nvim" = {
    source = kickstart;
    recursive = true;
  };

  home.packages = with pkgs; [
    neovim
    # Required dependencies for kickstart.nvim and its plugins (LSP, Tree-sitter, etc.)
    ripgrep
    fd
    clang
    nodejs
    tree-sitter
    unzip
    git # Required to clone plugins internally
  ];
}
