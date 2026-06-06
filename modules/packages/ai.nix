# modules/packages/ai.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my.packages.ai;

  # --- Level 7: Parallel Worktrees ---
  claude-parallel = pkgs.writeShellScriptBin "claude-parallel" ''
    SESSION="claude-parallel"

    if [[ "$1" == "--list" ]]; then
      claude agents --json
      exit 0
    fi

    if tmux has-session -t $SESSION 2>/dev/null; then
      tmux attach -t $SESSION
      exit 0
    fi

    FEAT_BRANCH="''${1:-feat/work}"
    FIX_BRANCH="''${2:-fix/work}"
    REFACTOR_BRANCH="''${3:-refactor/work}"

    tmux new-session -d -s $SESSION -n "feature"
    tmux send-keys -t $SESSION "cd $(pwd) && git worktree add /tmp/feat-work -b $FEAT_BRANCH && cd /tmp/feat-work && claude" Enter

    tmux new-window -t $SESSION -n "bugfix"
    tmux send-keys -t $SESSION "cd $(pwd) && git worktree add /tmp/fix-work -b $FIX_BRANCH && cd /tmp/fix-work && claude" Enter

    tmux new-window -t $SESSION -n "refactor"
    tmux send-keys -t $SESSION "cd $(pwd) && git worktree add /tmp/refactor-work -b $REFACTOR_BRANCH && cd /tmp/refactor-work && claude" Enter

    tmux select-window -t $SESSION:1
    tmux attach -t $SESSION
  '';

  # --- Level 8: Overnight Autonomous Mode ---
  overnight-claude = pkgs.writeShellScriptBin "overnight-claude" ''
    PROJECT="''${1:-$(pwd)}"
    TASK="$2"

    if [[ -z "$TASK" ]]; then
      echo "Usage: overnight-claude [project_path] 'task description'"
      exit 1
    fi

    echo "🌙 Starting overnight autonomous session (Opus 4.8)..."
    echo "Task: $TASK"

    tmux new-session -d -s overnight \
      "cd $PROJECT && claude \
        --dangerously-skip-permissions \
        --effort xhigh \
        --model claude-opus-4-8 \
        --fallback-model claude-sonnet-4-6 \
        --max-turns 500 \
        --output-format stream-json \
        -p '$TASK' \
        2>&1 | tee ~/.claude/overnight-$(date +%Y%m%d).log; \
        curl -X POST -H 'Content-Type: application/json' -d \"{\\\"text\\\": \\\"Overnight session for $PROJECT finished.\\\"}\" ''${TEAMS_WEBHOOK_URL:-#}"

    echo "✅ Running in background: tmux attach -t overnight"
  '';
in
{
  options.my.packages.ai = {
    enable = lib.mkEnableOption "AI Tools (Claude, Codex)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
      # inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs  # broken upstream
      inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.rtk
      pkgs.bash
      pkgs.jq
      pkgs.mcp-nixos
      pkgs.ruff
      pkgs.python3Packages.pytest
      pkgs.prettier
      pkgs.tmux
      pkgs.ripgrep
      pkgs.fd
      pkgs.gh
      pkgs.sops
      pkgs.age
      pkgs.nixfmt-rfc-style
      pkgs.uv
      claude-parallel
      overnight-claude
    ];

    # Level 6: Shell Aliases
    programs.fish.shellAliases = {
      claude-code = "claude --dangerously-skip-permissions";
    };

  };
}
