{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.productivity.shells;
in
{
  options.my.productivity.shells.enable =
    lib.mkEnableOption "Shell environments (bash, fish, starship)";

  config = lib.mkIf cfg.enable {
    programs = {
      bash = {
        enable = true;

        initExtra = ''
          export PATH="$HOME/.nix-profile/bin:$PATH"
          export HISTSIZE=100000
          export HISTFILESIZE=200000
          export HISTCONTROL=ignoreboth:erasedups
          shopt -s histappend
          PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
          source ${pkgs.fzf}/share/fzf/key-bindings.bash
          source ${pkgs.fzf}/share/fzf/completion.bash
          export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
          export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
          eval "$(zoxide init bash)"
          eval "$(starship init bash)"
          export LESS='-R --use-color -Dd+r$Du+b'
          export MANPAGER='bat -l man -p'
        '';

        historyControl = [
          "ignoredups"
          "erasedups"
        ];
      };

      fish = {
        enable = true;

        interactiveShellInit = ''
          fish_add_path $HOME/.nix-profile/bin
          set -g fish_greeting ""
          zoxide init fish | source
          fzf --fish | source
          bind \cr 'history | fzf --tac | read -l cmd; and commandline $cmd'
          pay-respects fish --alias | source
          set -gx LD_LIBRARY_PATH /usr/lib64:${
            lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.zstd
            ]
          }:$LD_LIBRARY_PATH
        '';

        functions = {
          mkcd = {
            description = "Create directory and enter it";
            body = "mkdir -p $argv && z $argv";
          };
          gcmt = {
            description = "Commit with ticket prefix from branch name";
            body = ''
              set ticket (git branch --show-current | rg -o -P '[A-Z]+-\d+')
              git commit -m "$ticket: $argv"
            '';
          };
          gbf = {
            description = "Fuzzy git branch switcher";
            body = ''
              git branch -a | fzf --height 40% | string trim | xargs git switch
            '';
          };
          ns = {
            description = "nix-shell with package";
            body = "nix shell nixpkgs#$argv[1]";
          };
        };
      };

      starship = {
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
  };
}
