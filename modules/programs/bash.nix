{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.bash;
  sharedAliases = import ../shared/aliases.nix;
in
{
  options.my.programs.bash = {
    enable = lib.mkEnableOption "Bash configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.bash = {
      enable = true;

      shellAliases = sharedAliases // {
        hm-switch = "nix-audit-session";
      };

      initExtra = ''
        # Add local binary path to PATH
        export PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"

        # Configure shell history for performance and deduplication
        export HISTSIZE=100000
        export HISTFILESIZE=200000
        export HISTCONTROL=ignoreboth:erasedups
        shopt -s histappend
        PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
      '';

      historyControl = [
        "ignoredups"
        "erasedups"
      ];
    };
  };
}
