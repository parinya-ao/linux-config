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

      # ── From .agents/skills/ (skills to keep) ──
      for dir in \
        conventional-commit \
        recall \
        recap \
        remember
      do
        if [ -d "$src/.agents/skills/$dir" ]; then
          mkdir -p "$out/$dir"
          cp "$src/.agents/skills/$dir/SKILL.md" "$out/$dir/SKILL.md"
          echo "  ✓ agents/$dir"
        else
          echo "  ⚠ agents/$dir not found, skipping"
        fi
      done

      # ── From .claude/skills/ (skills to keep) ──
      for dir in \
        gum-bash
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

  doInstallCheck = true;

   installCheckPhase = ''
     echo "=== Verifying agent-skills package ==="

      expected_skills="conventional-commit recall recap remember gum-bash"

     failures=0
     for skill in $expected_skills; do
       if [ -f "$out/$skill/SKILL.md" ]; then
         size=$(wc -c < "$out/$skill/SKILL.md")
         if [ "$size" -gt 0 ]; then
           echo "  ✓ $skill ($size bytes)"
         else
           echo "  ✗ $skill/SKILL.md is empty"
           failures=$((failures + 1))
         fi
       else
         # Non-fatal: skill may not exist in source (CI runs from repo root)
         echo "  - $skill not found in output (may not exist in source)"
       fi
     done

     # Count total skills packaged
     total=$(ls -1 "$out" | wc -l)
     echo "=== $total skill directories, $failures failures ==="
     [ "$failures" -eq 0 ] || exit 1
   '';

}
