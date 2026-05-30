{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.agent-skills;

  # Source: repo-root/.claude/skills/<name>/SKILL.md
  # These are the manually-managed skills shipped with the repo.
  skills = {
    gum-bash = ./../../.claude/skills/gum-bash/SKILL.md;
    react-doctor = ./../../.claude/skills/react-doctor/SKILL.md;
    nix-backup = ./../../.claude/skills/nix-backup/SKILL.md;
  };
in
{
  options.my.programs.agent-skills = {
    enable = lib.mkEnableOption "Agent skill files deployed via Home Manager";
  };

  config = lib.mkIf cfg.enable {
    # Deploy all skills to OpenCode's skill directory
    # ~/.config/opencode/skills/<name>/SKILL.md
    xdg.configFile = builtins.listToAttrs (
      builtins.map (name: {
        name = "opencode/skills/${name}/SKILL.md";
        value.source = skills.${name};
      }) (builtins.attrNames skills)
    );
  };
}
