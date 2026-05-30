{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.agent-skills;

  skills = {
    gum-bash = ./../../.claude/skills/gum-bash/SKILL.md;
    react-doctor = ./../../.claude/skills/react-doctor/SKILL.md;
    nix-backup = ./../../.claude/skills/nix-backup/SKILL.md;
  };

  # Every skill goes to all three agent directories
  targets = [
    ".config/opencode/skills"
    ".claude/skills"
    ".agents/skills"
  ];

  # Build home.file attrs: ".agents/skills/<name>/SKILL.md" -> { source = ... }
  skillEntries = builtins.listToAttrs (
    builtins.concatLists (
      builtins.map (
        name:
        builtins.map (target: {
          name = "${target}/${name}/SKILL.md";
          value.source = skills.${name};
        }) targets
      ) (builtins.attrNames skills)
    )
  );
in
{
  options.my.programs.agent-skills = {
    enable = lib.mkEnableOption "Agent skill files deployed via Home Manager";
  };

  config = lib.mkIf cfg.enable {
    home.file = skillEntries;
  };
}
