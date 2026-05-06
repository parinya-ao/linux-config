{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # From flake input
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Rust CLI replacements
    duf          # df replacement
    dust         # du replacement
    procs        # ps replacement
    bottom       # top/htop replacement
    gping        # ping with graph
    sd           # sed replacement (simpler syntax)
    choose       # cut/awk replacement
    xh           # curl/httpie replacement
    ouch         # compress/decompress everything
    zoxide       # smarter cd
    pay-respects
    mcfly        # smart shell history
    zellij       # modern tmux alternative

    # Dev tools
    tokei        # count lines of code
    hyperfine    # benchmarking tool
    watchexec    # auto-run on file change
    just         # modern Makefile (justfile)
    nix-tree     # visualize nix dependencies
    nvd          # nix diff between generations
  ];

  # eza (ls replacement)
  programs.eza = {
    enable               = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    icons                = "auto";
    git                  = true;     # show git status in ls
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--classify"
    ];
  };

  # bat (cat replacement)
  programs.bat = {
    enable = true;
    config = {
      theme       = "TwoDark";
      style       = "full";
      map-syntax  = [ "*.nix:Nix" "*.fish:fish" ];
    };
    extraPackages = with pkgs.bat-extras; [
      batdiff    # bat-powered git diff
      batman     # bat-powered man pages
      batgrep    # bat + ripgrep
      batwatch   # bat + watch
    ];
  };

  # direnv
  programs.direnv = {
    enable           = true;
    nix-direnv.enable = true;
    config = {
      global = {
        warn_timeout = "5s";
        load_dotenv  = true;
      };
    };
  };

  # fzf (fuzzy finder)
  programs.fzf = {
    enable               = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    defaultCommand       = "fd --type f --hidden --follow --exclude .git";
    defaultOptions       = [ "--height 40%" "--layout=reverse" "--border" "--info=inline" ];
    fileWidgetCommand    = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions    = [ "--preview 'bat --color=always --style=numbers {}'" ];
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    historyWidgetOptions = [ "--sort" "--exact" ];
    colors = {
      fg       = "#cdd6f4";
      "fg+"    = "#cdd6f4";
      bg       = "#1e1e2e";
      "bg+"    = "#313244";
      hl       = "#f38ba8";
      "hl+"    = "#f38ba8";
      info     = "#cba6f7";
      prompt   = "#cba6f7";
      pointer  = "#f5e0dc";
      marker   = "#f5e0dc";
      spinner  = "#f5e0dc";
      header   = "#f38ba8";
    };
  };

  # zoxide
  programs.zoxide = {
    enable               = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    options              = [ "--cmd z" ];  # keep z command name
  };

  # gemini-cli
  programs.gemini-cli = {
    enable  = true;
    package = pkgs.gemini-cli;
    settings = {
      security.auth.selectedType  = "oauth-personal";
      general.previewFeatures     = true;
    };
  };
}
