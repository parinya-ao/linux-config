{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "agent-skills";
  version = "1.0.0";

  meta = {
    description = "AI agent skill files for OpenCode, Claude Code, and AI Agents";
    longDescription = ''
      Collects all SKILL.md files from .agents/skills/ and .claude/skills/
      into a single Nix store path. Each skill becomes a subdirectory
      containing its SKILL.md. The store path is globally readable by all
      users on the system.
    '';
    license = lib.licenses.mit;
    maintainers = [ "parinya" ];
    platforms = lib.platforms.all;
  };

  src = ../..;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p "$out"

    echo "=== Packaging AI agent skills ==="

    # ── From .agents/skills/ (10 agentmemory/community skills) ──
    for dir in \
      bash-defensive-patterns \
      commit-context \
      commit-history \
      conventional-commit \
      forget \
      handoff \
      recall \
      recap \
      remember \
      session-history
    do
      if [ -d "$src/.agents/skills/$dir" ]; then
        mkdir -p "$out/$dir"
        cp "$src/.agents/skills/$dir/SKILL.md" "$out/$dir/SKILL.md"
        echo "  ✓ agents/$dir"
      else
        echo "  ⚠ agents/$dir not found, skipping"
      fi
    done

    # ── From .claude/skills/ (3 hand-crafted skills) ──
    for dir in \
      gum-bash \
      nix-backup \
      react-doctor
    do
      if [ -d "$src/.claude/skills/$dir" ]; then
        mkdir -p "$out/$dir"
        cp "$src/.claude/skills/$dir/SKILL.md" "$out/$dir/SKILL.md"
        echo "  ✓ claude/$dir"
      else
        echo "  ⚠ claude/$dir not found, skipping"
      fi
    done

    echo "=== Done — $(( $(ls -1 "$out" | wc -l) )) skills packaged ==="
  '';
}
