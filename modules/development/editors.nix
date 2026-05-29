{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.development.editors;
  kickstart = pkgs.fetchFromGitHub {
    owner = "nvim-lua";
    repo = "kickstart.nvim";
    rev = "cfdc17be3ae1607d4427332de0b29d556f9dda13";
    sha256 = "14bb9x2scbxzvaswcq7lnl868lirn3rjyr8y98rs20di9vhzki10";
  };
in
{
  options.my.development.editors.enable = lib.mkEnableOption "Code editors (Neovim)";

  config = lib.mkIf cfg.enable {
    xdg.configFile."nvim" = {
      source = kickstart;
      recursive = true;
    };

    home.packages = with pkgs; [
      neovim
      ripgrep
      fd
      clang
      nodejs
      tree-sitter
      unzip
      git
    ];
  };
}
