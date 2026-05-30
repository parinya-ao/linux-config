{ config, lib, ... }:

let
  cfg = config.my.suites;
in
{
  options.my.suites = {
    base.enable = lib.mkEnableOption "Base CLI & Shell tools";
    development.enable = lib.mkEnableOption "Development tools (Editor, Git, compilers)";
    ai.enable = lib.mkEnableOption "AI Tools & CLIs";
    desktop.enable = lib.mkEnableOption "GNOME Desktop & GUI apps";
  };

  config = {
    my.programs = {
      bash = lib.mkIf cfg.base.enable { enable = true; };
      fish = lib.mkIf cfg.base.enable { enable = true; };
      cli-tools = lib.mkIf cfg.base.enable { enable = true; };
      git = lib.mkIf cfg.development.enable { enable = true; };
      neovim = lib.mkIf cfg.development.enable { enable = true; };
      gnome = lib.mkIf cfg.desktop.enable { enable = true; };
      agent-skills = lib.mkIf cfg.ai.enable { enable = true; };
      mcp = lib.mkIf cfg.ai.enable { enable = true; };
      react-doctor = lib.mkIf cfg.ai.enable { enable = true; };
      opencode = lib.mkIf cfg.ai.enable { enable = true; };
      rtk = lib.mkIf cfg.ai.enable { enable = true; };
    };
    my.packages = {
      cli = lib.mkIf cfg.base.enable { enable = true; };
      dev = lib.mkIf cfg.development.enable { enable = true; };
      ai = lib.mkIf cfg.ai.enable { enable = true; };
      gui = lib.mkIf cfg.desktop.enable { enable = true; };
      docs = lib.mkIf cfg.desktop.enable { enable = true; };
      fonts = lib.mkIf cfg.desktop.enable { enable = true; };
    };
  };
}
