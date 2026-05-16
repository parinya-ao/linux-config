{
  config,
  lib,
  ...
}:
let
  cfg = config.my.programs.fish;
  sharedAliases = import ../shared/aliases.nix;
in
{
  options.my.programs.fish.enable = lib.mkEnableOption "fish shell and starship";

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        # PATH
        fish_add_path $HOME/.local/bin
        fish_add_path $HOME/.nix-profile/bin

        # Suppress greeting
        set -g fish_greeting ""

        # zoxide integration
        zoxide init fish | source

        # fzf integration
        fzf --fish | source

        # Keybindings: Ctrl+R → fzf history
        bind \cr 'history | fzf --tac | read -l cmd; and commandline $cmd'

        pay-respects fish --alias | source

      '';

      shellAliases = sharedAliases // {
        cdi = "zi"; # interactive jump

        # --- File tools ---
        llt = "eza --tree --level=3 --icons=auto -lh";

        # --- System ---
        cp = "cp -v";
        mv = "mv -v";
        rm = "rm -Iv"; # capital I = prompt once if removing >3 files
        mkdir = "mkdir -pv";
        disk = "lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL";

        # --- Git (power shortcuts) ---
        g = "git";
        ga = "git add";
        gaa = "git add .";
        gap = "git add -p"; # interactive patch staging
        gc = "git commit";
        gcm = "git commit -m";
        gca = "git commit --amend --no-edit";
        gst = "git status -sb";
        gb = "git branch -vv";
        gch = "git switch"; # modern replacement for checkout
        gcb = "git switch -c";
        gp = "git push";
        gpf = "git push --force-with-lease"; # safe force push
        gpl = "git pull --rebase";
        gd = "git diff";
        gds = "git diff --staged";
        glog = "git log --oneline --graph --decorate -20";
        gloga = "git log --oneline --graph --decorate --all";
        gwip = "git add -A && git commit -m 'wip: checkpoint'";
        gunwip = "git log -n 1 --pretty=%B | rg -q 'wip' && git reset HEAD~";
        gclean = "git branch --merged | rg -v main | xargs git branch -d";

        # --- Dev shortcuts ---
        nix-clean = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
        nix-update = "nix flake update";
        nix-rebuild = "sudo nixos-rebuild switch --flake .#";
        hm-switch = "nix-audit-session";
      };

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
