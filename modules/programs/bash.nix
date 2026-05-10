{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.bash;
in
{
  options.my.programs.bash = {
    enable = lib.mkEnableOption "Bash configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.bash = {
      enable = true;

      shellAliases = {
        ls = "eza --icons=auto --group-directories-first";
        ll = "eza -lhF --icons=auto --git --group-directories-first";
        la = "eza -lahF --icons=auto --git";
        lt = "eza --tree --level=2 --icons=auto";
        cat = "bat --style=full";
        find = "fd";
        grep = "rg --color=auto --smart-case";
        sed = "sd";
        awk = "choose";
        cut = "choose";
        diff = "delta";
        man = "batman";
        tree = "eza --tree";
        curl = "xh";
        df = "duf";
        du = "dust";
        ps = "procs";
        top = "btm";
        htop = "btm";
        ping = "gping";
        cd = "z";
        ".." = "z ..";
        "..." = "z ../..";
        ".4" = "z ../../..";
      };

      initExtra = ''
        # Add local binary path to PATH
        export PATH="$HOME/.nix-profile/bin:$PATH"

        # Configure shell history for performance and deduplication
        export HISTSIZE=100000
        export HISTFILESIZE=200000
        export HISTCONTROL=ignoreboth:erasedups
        shopt -s histappend
        PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

        # Initialize fzf keybindings and fuzzy completion
        source ${pkgs.fzf}/share/fzf/key-bindings.bash
        source ${pkgs.fzf}/share/fzf/completion.bash
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

        # Initialize zoxide (smarter cd)
        eval "$(zoxide init bash)"

        # Initialize Starship prompt
        eval "$(starship init bash)"

        # Configure bat as the pager for improved man page readability
        export LESS='-R --use-color -Dd+r$Du+b'
        export MANPAGER='bat -l man -p'
      '';

      historyControl = [
        "ignoredups"
        "erasedups"
      ];
    };
  };
}
