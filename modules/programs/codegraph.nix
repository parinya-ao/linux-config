{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.programs.codegraph;

  codegraph-wrapper = pkgs.writeShellScriptBin "codegraph" ''
    exec ${lib.getExe pkgs.bun} x --yes @colbymchenry/codegraph@latest "$@"
  '';
in
{
  options.my.programs.codegraph = {
    enable = lib.mkEnableOption "CodeGraph — pre-indexed code knowledge graph for AI agents";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      codegraph-wrapper
      bun
    ];

    home.activation.setupCodeGraph = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${codegraph-wrapper}/bin/codegraph install \
        --yes \
        --target=auto \
        --location=global
    '';
  };
}
