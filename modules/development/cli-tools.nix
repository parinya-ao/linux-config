{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.development.cli-tools;
in
{
  options.my.development.cli-tools.enable = lib.mkEnableOption "Core CLI tools & modern replacements";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      tmux
      jq
      curl
      wget
      lsd
      fastfetch
      tldr
      p7zip
      xclip
      htop
      duf
      dust
      procs
      bottom
      gping
      sd
      choose
      xh
      ouch
      pay-respects
      mcfly
      zellij
      tokei
      hyperfine
      watchexec
      just
      nix-tree
      nvd
    ];

    programs = {
      eza = {
        enable = true;
        enableFishIntegration = true;
        enableBashIntegration = true;
        icons = "auto";
        git = true;
        extraOptions = [
          "--group-directories-first"
          "--header"
          "--classify"
        ];
      };

      bat = {
        enable = true;
        config = {
          theme = "TwoDark";
          style = "full";
          map-syntax = [
            "*.nix:Nix"
            "*.fish:fish"
          ];
        };
        extraPackages = with pkgs.bat-extras; [
          batdiff
          batman
          batgrep
          batwatch
        ];
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
        config.global = {
          warn_timeout = "5s";
          load_dotenv = true;
        };
      };
    };

    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--info=inline"
      ];
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetOptions = [ "--preview 'bat --color=always --style=numbers {}'" ];
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      historyWidgetOptions = [
        "--sort"
        "--exact"
      ];
      colors = {
        fg = "#cdd6f4";
        "fg+" = "#cdd6f4";
        bg = "#1e1e2e";
        "bg+" = "#313244";
        hl = "#f38ba8";
        "hl+" = "#f38ba8";
        info = "#cba6f7";
        prompt = "#cba6f7";
        pointer = "#f5e0dc";
        marker = "#f5e0dc";
        spinner = "#f5e0dc";
        header = "#f38ba8";
      };
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
      options = [ "--cmd z" ];
    };
  };
}
