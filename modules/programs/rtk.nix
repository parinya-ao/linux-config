{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.rtk;
  initMarker = "$HOME/.config/rtk/.opencode-init-done";
in
{
  options.my.programs.rtk = {
    enable = lib.mkEnableOption "RTK — LLM token optimizer (auto-init with OpenCode)";
  };

  config = lib.mkIf cfg.enable {
    home.activation = {
      rtkInitOpenCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${initMarker}" ]; then
          echo "n" | $DRY_RUN_CMD env RTK_TELEMETRY_DISABLED=1 ${lib.getExe pkgs.rtk} init -g --opencode
          $DRY_RUN_CMD ${lib.getExe pkgs.rtk} telemetry disable >/dev/null 2>&1 || true
          mkdir -p "$(dirname "${initMarker}")"
          touch "${initMarker}"
        fi
      '';
    };
  };
}
