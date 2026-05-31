{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "agent-skills";
  version = "1.0.0";

  src = ./.;

  meta = {
    description = "AI agent skill files for OpenCode, Claude Code, and AI Agents";
    longDescription = ''
      Packages all SKILL.md files from the pkgs/agent-skills/ directory
      into a single Nix store path. Each skill becomes a subdirectory
      containing its SKILL.md plus any optional references/ and scripts/.
      The store path is globally readable by all users on the system.
    '';
    license = lib.licenses.mit;
    maintainers = [ "parinya" ];
    platforms = lib.platforms.all;
  };

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p "$out"

    echo "=== Packaging AI agent skills ==="

    for skill_dir in "$src"/*/; do
      skill_dir=''${skill_dir%/}

      # Skip standard files, only process real directories
      [ -f "$skill_dir" ] && continue

      skill_name=$(basename "$skill_dir")

      if [ -f "$skill_dir/SKILL.md" ]; then
        mkdir -p "$out/$skill_name"
        cp "$skill_dir"/SKILL.md "$out/$skill_name/SKILL.md"
        echo "  ✓ $skill_name (SKILL.md)"

        # Optionally ship references/ and scripts/
        [ -d "$skill_dir/references" ] && (
          mkdir -p "$out/$skill_name/references"
          cp -r "$skill_dir/references/"* "$out/$skill_name/references/"
          echo "    └─ references/"
        )
        [ -d "$skill_dir/scripts" ] && (
          mkdir -p "$out/$skill_name/scripts"
          cp -r "$skill_dir/scripts/"* "$out/$skill_name/scripts/"
          echo "    └─ scripts/"
        )
      fi
    done

    echo "=== Done — $(( $(ls -1 "$out" | wc -l) )) skills packaged ==="
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    echo "=== Verifying agent-skills package ==="

    expected_skills="conventional-commit gum-bash nix-config recall recap remember typescript"

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
        echo "  ✗ $skill not found in output"
        failures=$((failures + 1))
      fi
    done

    total=$(ls -1 "$out" | wc -l)
    echo "=== $total skill directories, $failures failures ==="
    [ "$failures" -eq 0 ] || exit 1
  '';
}
