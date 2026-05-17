{
  config,
  lib,
  ...
}:
let
  cfg = config.my.programs.git;
in
{
  options.my.programs.git.enable = lib.mkEnableOption "Git and Delta";

  config = lib.mkIf cfg.enable {
    programs.delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "TwoDark";
        minus-style = "syntax \"#450a15\"";
        plus-style = "syntax \"#0d2a12\"";
      };
    };

    programs.git = {
      enable = true;
      signing = {
        format = "ssh";
        key = "~/.ssh/id_ed25519";
        signByDefault = true;
      };

      # Use settings attribute set instead of extraConfig for better modularity
      settings = {
        alias = {
          amend = "commit --amend --no-edit";
          wip = "!git add -A && git commit -m 'wip: checkpoint'";
          unwip = "!git log -n 1 --pretty=%B | rg -q 'wip' && git reset HEAD~";
          undo = "reset --soft HEAD~1";
          unstage = "restore --staged";
          lg = "log --oneline --graph --decorate --all";
          stash-all = "stash push --include-untracked";
          recent = "branch --sort=-committerdate --format='%(committerdate:relative)%09%(refname:short)'";
        };

        user = {
          name = "parinya-ao";
          email = "flim.parinya.ao@gmail.com";
        };

        init.defaultBranch = "main";

        pack.threads = 0;
        checkout.workers = 0;
        feature.manyFiles = true;

        push.autoSetupRemote = true;
        push.default = "current";
        pull.rebase = true;
        rebase = {
          autoStash = true;
          updateRefs = true;
        };
        merge.ff = "only";

        color.ui = "auto";
        rerere.enabled = true;
        rerere.autoUpdate = true;
        maintenance.auto = true;
        help.autocorrect = 10;

        diff = {
          algorithm = "histogram";
          colorMoved = "default";
          colorMovedWS = "allow-indentation-change";
        };
      };
    };
  };
}
