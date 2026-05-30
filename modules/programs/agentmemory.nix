{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.agentmemory;

  agentmemory-wrapper = pkgs.writeShellScriptBin "agentmemory" ''
    exec ${lib.getExe pkgs.bun} x --yes @agentmemory/agentmemory@latest "$@"
  '';

  agentmemory-mcp = pkgs.writeShellScriptBin "agentmemory-mcp" ''
    exec ${lib.getExe pkgs.bun} x --yes @agentmemory/mcp@latest "$@"
  '';
in
{
  options.my.programs.agentmemory = {
    enable = lib.mkEnableOption "AgentMemory — persistent memory server for AI agents";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      agentmemory-wrapper
      agentmemory-mcp
      bun
    ];

    # Background server for agentmemory (REST API on :3111, viewer on :3113)
    systemd.user.services.agentmemory = {
      Unit = {
        Description = "AgentMemory Persistent Memory Server";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${agentmemory-wrapper}/bin/agentmemory";
        Restart = "on-failure";
        RestartSec = "5";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Wire MCP for opencode + other agents
    home.activation.setupAgentMemory = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
      $DRY_RUN_CMD ${agentmemory-wrapper}/bin/agentmemory connect claude-code || true
      $DRY_RUN_CMD ${agentmemory-wrapper}/bin/agentmemory connect codex || true
      $DRY_RUN_CMD ${agentmemory-wrapper}/bin/agentmemory connect opencode || true
      $DRY_RUN_CMD ${pkgs.bun}/bin/bun x --yes skills@latest add rohitg00/agentmemory -y -a '*' || true
    '';
  };
}
