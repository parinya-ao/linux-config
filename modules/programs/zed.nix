{ pkgs, lib, ... }:

{
  programs.zed-editor = {
    enable = true;

    # Extensions to pre-install
    extensions = [
      "nix"
      "toml"
      "rust"
      "python"
      "json"
      "yaml"
      "markdown"
      "bash"
      "fish"
      "git-firefly"
    ];

    # Include remote server support for SSH collaboration
    installRemoteServer = true;

    # Additional packages for LSP servers in FHS environment
    extraPackages = with pkgs; [
	    rust-analyzer
      nixd
      pyright
      bash-language-server
      shfmt
      shellcheck
    ];

    # User settings and configuration
    userSettings = {
      # Theme and appearance
      theme = {
        mode = "system";
        dark = "One Dark";
        light = "One Light";
      };

      # Time format
      hour_format = "hour24";

      # Vim mode enabled
      vim_mode = true;

      # Auto-update disabled (using nix for updates)
      auto_update = false;

      # Editor font and sizing
      ui_font_size = 14;
      buffer_font_size = 13;
      font_family = "FiraCode Nerd Font";
      line_height = "comfortable";

      # Whitespace visibility
      show_whitespaces = "all";

      # Terminal configuration
      terminal = {
        dock = "bottom";
        detect_venv = {
          on = {
            directories = [ ".env" "env" ".venv" "venv" ];
            activate_script = "default";
          };
        };
        env = {
          TERM = "alacritty";
        };
        shell = "system";
        working_directory = "current_project_directory";
      };

      # LSP configuration
      lsp = {
        rust-analyzer = {
          binary = {
            path_lookup = true;
          };
        };

        nix = {
          binary = {
            path_lookup = true;
          };
        };

        pyright = {
          binary = {
            path_lookup = true;
          };
        };

        bash-language-server = {
          binary = {
            path_lookup = true;
          };
        };
      };

      # Language-specific settings
      languages = {
        "Rust" = {
          format_on_save = "on";
          formatter = {
            external = {
              command = "rustfmt";
              arguments = [ "--edition" "2021" ];
            };
          };
        };

        "Nix" = {
          language_servers = [ "!nil" "nixd" ];
          format_on_save = {
            external = {
              command = "alejandra";
              arguments = [ "-" ];
            };
          };
        };

        "Python" = {
          language_servers = [ "pyright" ];
          format_on_save = "on";
          formatter = {
            external = {
              command = "black";
              arguments = [ "-" ];
            };
          };
        };

        "Bash" = {
          language_servers = [ "bash-language-server" ];
          format_on_save = {
            external = {
              command = "shfmt";
              arguments = [ "-i" "2" "-" ];
            };
          };
        };
      };

      # Other settings
      load_direnv = "shell_hook";
      base_keymap = "VSCode";

      # Use git to determine project root
      project_panel = {
        auto_reveal_entries = true;
      };
    };

    # Optional: User keymaps can be added here
    # userKeymaps = [ ... ];
  };

  # Optional: Add Zed to easily accessible location
  home.shellAliases = {
    zed = "zeditor";
  };
}
