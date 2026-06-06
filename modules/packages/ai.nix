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

    home.file = {
      ".claude/settings.json" = {
        force = true;
        text = builtins.toJSON {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
          model = "claude-sonnet-4-5-20250929";

          permissions = {
            defaultMode = "acceptEdits";
            allow = [
              "Read"
              "Glob"
              "Grep"
              "Bash(git:*)"
              "Bash(python3:*)"
              "Bash(npm run:*)"
              "Bash(nix:*)"
              "Bash(make:*)"
              "Bash(ruff:*)"
              "Bash(pytest:*)"
              "Bash(npx prettier:*)"
              "Bash(nixfmt:*)"
              "Bash(gh:*)"
              "Edit(src/**)"
              "Write(src/**)"
              "mcp__github__*"
              "mcp__nixos__*"
              "mcp__context7__*"
              "mcp__memory__*"
            ];
            deny = [
              "Read(.env*)"
              "Read(**/secrets/**)"
              "Read(**/*.pem)"
              "Bash(rm -rf:*)"
              "Bash(sudo:*)"
              "Bash(curl|wget:*)"
              "Bash(git push --force:*)"
              "Bash(git reset --hard:*)"
              "Bash(pkill:*)"
              "Bash(systemctl stop:*)"
            ];
            ask = [
              "WebFetch"
              "Bash(ssh:*)"
              "Bash(docker:*)"
            ];
            additionalDirectories = [
              "../shared-lib"
              "~/reference"
            ];
          };

          mcpServers = {
            github = {
              command = "docker";
              args = [
                "run"
                "-i"
                "--rm"
                "-e"
                "GITHUB_PERSONAL_ACCESS_TOKEN"
                "ghcr.io/github/github-mcp-server"
              ];
              env = {
                GITHUB_PERSONAL_ACCESS_TOKEN = "\$" + "{GITHUB_TOKEN}";
              };
            };
            nixos = {
              command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            };
            context7 = {
              command = "npx";
              args = [ "-y" "@upstash/context7-mcp" ];
            };
            memory = {
              command = "npx";
              args = [ "-y" "@modelcontextprotocol/server-memory" ];
            };
            fetch = {
              command = "npx";
              args = [ "-y" "@modelcontextprotocol/server-fetch" ];
            };
            filesystem = {
              command = "npx";
              args = [ "-y" "@modelcontextprotocol/server-filesystem" "$(pwd)" ];
            };
            "sequential-thinking" = {
              command = "npx";
              args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
            };
          };

          env = {
            ANTHROPIC_MODEL = "claude-sonnet-4-5";
            CLAUDE_CODE_SUBAGENT_MODEL = "claude-haiku-4-5";
            MAX_THINKING_TOKENS = "10000";
            BASH_DEFAULT_TIMEOUT_MS = "60000";
            BASH_MAX_TIMEOUT_MS = "600000";
            BASH_MAX_OUTPUT_LENGTH = "100000";
            DISABLE_TELEMETRY = "0";
            DISABLE_PROMPT_CACHING = "0";
            DISABLE_NON_ESSENTIAL_MODEL_CALLS = "0";
            OTEL_LOG_TOOL_DETAILS = "1";
          };

          sandbox = {
            enabled = false;
            autoAllowBashIfSandboxed = true;
          };

          autoMemoryEnabled = true;
          autoDreamEnabled = true;
          autoCompactWindow = 33000;
          fileCheckpointingEnabled = true;
          alwaysThinkingEnabled = true;
          effortLevel = "thorough";
          advisorModel = "claude-haiku-4-5";
          showThinkingSummaries = true;
          "fallback-model" = "claude-sonnet-4-6";
          attribution = {
            commit = true;
            pr = true;
          };
          autoConnectIde = true;
          autoInstallIdeExtension = true;
          enableAllProjectMcpServers = true;
          voiceEnabled = true;

          outputStyle = "Explanatory";
          showTurnDuration = true;
          plansDirectory = ".claude/plans";
          respectGitignore = true;
          cleanupPeriodDays = 30;

          statusLine = {
            type = "command";
            command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
            padding = 0;
          };

          hooks = {
            SessionStart = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/session-start.sh";
                  }
                ];
              }
            ];
            UserPromptSubmit = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/user-prompt-submit.sh";
                  }
                ];
              }
            ];
            MessageDisplay = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/message-display.sh";
                  }
                ];
              }
            ];
            SessionEnd = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/session-end.sh";
                  }
                ];
              }
            ];
            CwdChanged = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/cwd-changed.sh";
                  }
                ];
              }
            ];
            Notification = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/notification.sh";
                    terminalSequence = true;
                  }
                ];
              }
            ];
            PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/audit-bash.sh";
                  }
                ];
              }
              {
                matcher = "Read|Edit|Write";
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/protect-secrets.sh";
                  }
                ];
              }
            ];
            PostToolUse = [
              {
                matcher = "Edit|Write";
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/auto-format.sh";
                  }
                ];
              }
            ];
            SubagentStop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/subagent-stop.sh";
                  }
                ];
              }
            ];
            Stop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "~/.claude/hooks/gate-completion.sh";
                  }
                ];
              }
            ];
          };
        };
      };

      ".claude/rules/python.md" = {
        text = ''
          # Python Development Rules
          - Primary stack: Python 3.12+, FastAPI
          - I prefer typed Python with full type hints at all times
          - Run `ruff check` + `ruff format` after any Python file edits
          - Prefer `uv` for package management over `pip`
          - Follow PEP 8 and use modern Python features (e.g., f-strings, type unions)
        '';
      };

      ".claude/rules/nix.md" = {
        text = ''
          # Nix & Home Manager Rules
          - Use Nix Flakes for all dependency management
          - Follow modular pattern for Home Manager: split packages/programs
          - Use `nixfmt` (rfc-style) after every `.nix` file edit
          - Always verify builds with `nix build` or `home-manager build`
          - Prefer `lib.mkIf` and `lib.mkEnableOption` for modular configuration
        '';
      };

      ".claude/rules/security.md" = {
        text = ''
          # IT Security Rules
          - NEVER hardcode credentials, tokens, or keys anywhere
          - Always suggest environment variable / vault pattern for secrets
          - Flag any code that could be an injection vector (SQL, shell, path traversal)
          - For network-facing code, always recommend TLS + input validation
          - Use `sops` or `age` for local secret management
        '';
      };

      ".claude/rules/git.md" = {
        text = ''
          # Git & Workflow Rules
          - Use Conventional Commits (feat, fix, chore, etc.)
          - Never push to main/master directly; use feature branches
          - Use `git worktree` for parallel task management via `claude-parallel`
          - Always check `git status` before committing
          - Prefer `git commit -v` to review changes before finalizing
        '';
      };

      ".claude/CLAUDE.md" = {
        text = ''
          # Global Instructions for Claude Code

          @import "./rules/python.md"
          @import "./rules/nix.md"
          @import "./rules/security.md"
          @import "./rules/git.md"

          ## Identity & Context
          - I am an IT/AI engineer working primarily on Python, Linux (Fedora/openSUSE), and enterprise automation
          - Primary stack: Python, NixOS, Ansible, ServiceNow

          ## Behavior Rules
          - Never modify files under `./migrations/` without explicit confirmation
          - Always explain WHY you're making a change, not just WHAT you're changing
          - If you're uncertain, ASK — don't guess
          - Prefer explicit over implicit in all code
          - When writing bash/shell: use `set -euo pipefail` at the top

          ## Learning Mode
          - After making changes, briefly explain design decisions
          - If I correct you, say "Updating rule: [X]"
        '';
      };

      ".claude/commands/security-audit.md" = {
        text = ''
          # Security Audit Command

          Perform a comprehensive security analysis on the current codebase or specific files.

          ## Checklist
          1. **Injection Vulnerabilities**: Check for SQL, Shell, and Path Traversal risks.
          2. **Credential Safety**: Ensure no hardcoded keys, tokens, or secrets.
          3. **Input Validation**: Verify all network-facing inputs are properly sanitized.
          4. **Cryptography**: Check for insecure random numbers or weak hash algorithms.
          5. **Dependencies**: Identify outdated or vulnerable packages if possible.

          ## Output Format
          - **Summary**: A high-level overview of the security posture.
          - **Findings**: A list of specific issues with severity (Critical/High/Medium/Low).
          - **Remediation**: Actionable steps to fix each identified issue.
        '';
      };

      ".claude/hooks/session-start.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          branch=$(git branch --show-current 2>/dev/null)
          last_commit=$(git log --oneline -1 2>/dev/null)
          pending_tests=$(python3 -m pytest --collect-only -q 2>/dev/null | tail -1)
          # Level 8: Output as JSON for context injection + skill reload
          echo "{\"additionalContext\": \"[SESSION] Branch: $branch | Last: $last_commit | Tests: $pending_tests\", \"reloadSkills\": true}"
          exit 0
        '';
      };

      ".claude/hooks/user-prompt-submit.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Dynamic context injection before every prompt
          uptime_info=$(uptime -p)
          git_status=$(git status --short 2>/dev/null | head -5)
          echo "{\"additionalContext\": \"[SYSTEM] Uptime: $uptime_info | Git Status: $git_status\"}"
          exit 0
        '';
      };

      ".claude/hooks/message-display.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Filter verbose output or transform messages
          cat
          exit 0
        '';
      };

      ".claude/hooks/subagent-stop.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          echo "{\"additionalContext\": \"Subagent finished at $(date)\"}"
          exit 0
        '';
      };

      ".claude/hooks/session-end.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Cleanup and notification
          echo "[$(date)] Session Ended" >> ~/.claude/session.log
          exit 0
        '';
      };

      ".claude/hooks/cwd-changed.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          new_cwd=$(cat)
          echo "[CWD] Switched to $new_cwd" >> ~/.claude/audit.log
          exit 0
        '';
      };

      ".claude/hooks/notification.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Send desktop notification
          data=$(cat)
          msg=$(echo "$data" | jq -r '.message // "Claude Task Update"')
          notify-send "Claude Code" "$msg"
          exit 0
        '';
      };

      ".claude/hooks/audit-bash.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          data=$(cat)
          cmd=$(echo "$data" | jq -r '.tool_input.command // empty')
          echo "[$(date '+%H:%M:%S')] CMD: $cmd" >> ~/.claude/audit.log
          exit 0
        '';
      };

      ".claude/hooks/protect-secrets.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          data=$(cat)
          path=$(echo "$data" | jq -r '.tool_input.file_path // empty')
          [[ "$path" == *".env"* ]] && echo "BLOCKED: $path" >&2 && exit 2
          [[ "$path" == *"secrets/"* ]] && echo "BLOCKED: $path" >&2 && exit 2
          [[ "$path" == *".pem"* ]] && echo "BLOCKED: $path" >&2 && exit 2
          exit 0
        '';
      };

      ".claude/hooks/auto-format.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          data=$(cat)
          file=$(echo "$data" | jq -r '.tool_input.file_path // empty')
          [[ "$file" == *.py ]] && ruff check --fix "$file" 2>/dev/null && ruff format "$file" 2>/dev/null
          [[ "$file" == *.nix ]] && nixfmt "$file" 2>/dev/null
          [[ "$file" == *.ts || "$file" == *.js ]] && npx prettier --write "$file" 2>/dev/null
          exit 0
        '';
      };

      ".claude/hooks/gate-completion.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          # Infinite loop guard
          if [[ -f /tmp/claude_stop_hook_active ]]; then
            exit 0
          fi
          touch /tmp/claude_stop_hook_active
          trap 'rm -f /tmp/claude_stop_hook_active' EXIT

          result=$(python3 -m pytest -x -q --tb=no 2>&1 | tail -3)
          if echo "$result" | grep -q "failed"; then
            echo "{\"additionalContext\": \"⛔ TESTS FAILING — Fix before stopping: $result\"}" >&2
            exit 2
          fi
          exit 0
        '';
      };

      ".claude/agents/security-auditor.md" = {
        text = ''
          ---
          name: security-auditor
          model: claude-opus-4-5
          description: Deep security analysis agent for code and infrastructure
          color: red
          tools: Read, Glob, Grep, Bash
          ---

          You are a senior security engineer. For every analysis:
          1. Check injection vectors: SQL, shell, path traversal, SSTI
          2. Check authentication/authorization bypass opportunities
          3. Check hardcoded secrets, weak crypto, insecure random
          4. Check dependency CVEs via `pip-audit` or `npm audit`
          5. Output SARIF-compatible findings with severity: CRITICAL/HIGH/MEDIUM/LOW
        '';
      };

      ".claude/agents/patch-analyst.md" = {
        text = ''
          ---
          name: patch-analyst
          model: claude-haiku-4-5
          description: Analyze CVEs and security advisories for patch priority
          color: orange
          tools: Read, WebFetch, Bash
          ---

          For each CVE or advisory provided:
          1. Assess affected components in our stack (Python, Linux, Node.js)
          2. Check version ranges vs our installed versions
          3. Rate remediation urgency: P1(critical)/P2(high)/P3(medium)/P4(low)
          4. Draft ServiceNow change request summary
          5. Suggest rollback plan if patch breaks things
        '';
      };

      ".claude/agents/nix-builder.md" = {
        text = ''
          ---
          name: nix-builder
          model: claude-sonnet-4-5
          description: NixOS configuration and flakes specialist
          tools: Read, Edit, Write, Bash(nix:*), Bash(nixos-rebuild:*)
          ---

          You specialize in NixOS/Home Manager. Always:
          - Check `nixos-unstable` for latest package versions
          - Use `nix fmt` after every `.nix` file edit
          - Verify builds with `nix build` before suggesting `nixos-rebuild`
          - Handle FHS incompatibility issues on NixOS
          - Generate reproducible flake.lock with `nix flake update`
        '';
      };
    };
  };
}
