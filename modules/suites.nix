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

  config = lib.mkMerge [
    # Base Suite: What you want on EVERY machine
    (lib.mkIf cfg.base.enable {
      my = {
        programs = {
          bash.enable = true;
          fish.enable = true;
          cli-tools.enable = true;
        };
        packages.cli.enable = true;
      };
    })

    # Development Suite
    (lib.mkIf cfg.development.enable {
      my = {
        programs = {
          git.enable = true;
          neovim.enable = true;
        };
        packages.dev.enable = true;
      };
    })

    # AI Suite
    (lib.mkIf cfg.ai.enable {
      my.packages.ai.enable = true;
    })

    # Desktop Suite
    (lib.mkIf cfg.desktop.enable {
      my = {
        programs.gnome.enable = true;
        packages = {
          gui.enable = true;
          docs.enable = true;
        };
      };
    })
  ];
}
