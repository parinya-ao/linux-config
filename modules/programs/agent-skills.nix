{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.agent-skills;

  # ── All skills sourced from pkgs.agent-skills (Nix store) ──
  allSkills = [
    "conventional-commit"
    "gum-bash"
    "nix-config"
    "recall"
    "recap"
    "remember"
  ];

  # Default + user extras
  targetDirs = [
    ".config/opencode/skills"
    ".claude/skills"
    ".agents/skills"
    ".codex/skills"
  ]
  ++ cfg.extraTargetDirs;

  # Build a flat list of { name, value } for each skill × dir
  # Links the entire skill directory (includes references/, scripts/ if present)
  entryList = builtins.foldl' (
    acc: dir:
    acc
    ++ builtins.foldl' (
      acc2: skill:
      acc2
      ++ [
        {
          name = "${dir}/${skill}";
          value = {
            source = "${pkgs.agent-skills}/${skill}";
            recursive = true;
          };
        }
      ]
    ) [ ] allSkills
  ) [ ] targetDirs;

  skillEntries = builtins.listToAttrs entryList;

  globalEntry =
    if cfg.globalDir != null then
      {
        "${cfg.globalDir}" = {
          source = pkgs.agent-skills;
          recursive = true;
        };
      }
    else
      { };
in
{
  options.my.programs.agent-skills = {
    enable = lib.mkEnableOption "AI agent skill files deployed via Home Manager";

    extraTargetDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional relative home directories to install skills into.
        Each entry is a path under $HOME (e.g. ".cursor/skills").
      '';
      example = [
        ".cursor/skills"
        ".windsurf/skills"
      ];
    };

    globalDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ".local/share/agent-skills";
      description = ''
        Central shared skill directory under $HOME.
        Set to null to disable. All agents that support a SKILLS_DIR
        or custom skills path can point here.
      '';
      example = ".local/share/agent-skills";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = skillEntries // globalEntry;
  };
}
