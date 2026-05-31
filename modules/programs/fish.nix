{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.programs.fish;
in
{
  options.my.programs.fish.enable = lib.mkEnableOption "fish shell and starship";

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        # PATH
        fish_add_path $HOME/.nix-profile/bin

        # Suppress greeting
        set -g fish_greeting ""

        # zoxide integration
        zoxide init fish | source

        # fzf integration
        fzf --fish | source

        # Keybindings: Ctrl+R → fzf history
        bind \cr 'history | fzf --tac | read -l cmd; and commandline $cmd'

        # pay-respects fish --alias | source  # Removed aliases

        # uv 
        set -gx LD_LIBRARY_PATH /usr/lib64:${
          lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.zstd
          ]
        }:$LD_LIBRARY_PATH
      '';

      functions = {
        # Create dir and cd into it
        mkcd = {
          description = "Create directory and enter it";
          body = "mkdir -p $argv && z $argv";
        };

        # Quick git commit with ticket prefix
        gcmt = {
          description = "Commit with ticket prefix from branch name";
          body = ''
            set ticket (git branch --show-current | rg -o -P '[A-Z]+-\d+')
            git commit -m "$ticket: $argv"
          '';
        };

        # fzf-powered branch switcher
        gbf = {
          description = "Fuzzy git branch switcher";
          body = ''
            git branch -a | fzf --height 40% | string trim | xargs git switch
          '';
        };

        # Quick nix shell
        ns = {
          description = "nix-shell with package";
          body = "nix shell nixpkgs#$argv[1]";
        };
      };
    };

    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
        add_newline = true;
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
          vimcmd_symbol = "[❮](bold yellow)";
        };
        directory = {
          style = "bold cyan";
          truncation_length = 3;
          truncate_to_repo = true;
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        git_status = {
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          modified = "!";
          staged = "+";
          untracked = "?";
          stashed = "≡";
        };
        nix_shell = {
          symbol = " ";
          style = "bold blue";
        };
        cmd_duration = {
          min_time = 2000;
          format = "took [$duration](bold yellow) ";
        };
      };
    };
  };
}
