{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.mcp;
in
{
  options.my.programs.mcp = {
    enable = lib.mkEnableOption "MCP servers (claude-mem + sequential-thinking)";
  };

  config = lib.mkIf cfg.enable {

    # Sequential Thinking MCP server config for OpenCode
    xdg.configFile."opencode/mcp.json".text = builtins.toJSON {
      mcpServers = {
        sequential-thinking = {
          command = "bunx";
          args = [
            "-y"
            "@modelcontextprotocol/server-sequential-thinking"
          ];
        };
      };
    };

    # Claude-Mem persistent memory daemon (background worker, port ~37700)
    # Uses Type=oneshot because claude-mem start spawns a daemon and exits.
    systemd.user.services.claude-mem-worker = {
      Unit = {
        Description = "Claude-Mem Persistent Memory Worker";
        After = [ "network.target" ];
      };
      Service = {
        Type = "forking";
        ExecStart = "${lib.getExe pkgs.bun} x claude-mem start";
        ExecStop = "${lib.getExe pkgs.bun} x claude-mem stop";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Activation script: install claude-mem hooks for OpenCode and Codex
    home.activation.setupClaudeMem = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${lib.getExe pkgs.bun} x claude-mem install --ide opencode || true
      $DRY_RUN_CMD ${lib.getExe pkgs.bun} x claude-mem install --ide codex-cli || true
    '';
  };
}
