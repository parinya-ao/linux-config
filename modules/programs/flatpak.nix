{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.my.programs.flatpak;
in
{
  # Imports the nix-flatpak module for declarative Flatpak management.
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  options.my.programs.flatpak = {
    enable = lib.mkEnableOption "Declarative Flatpak management";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;
      packages = [
        "com.discordapp.Discord"
        "com.obsproject.Studio"
        "md.obsidian.Obsidian"
        "com.rustdesk.RustDesk"
        "org.signal.Signal"
        "com.github.tchx84.Flatseal"
        "com.usebruno.Bruno"
        "io.dbeaver.DBeaverCommunity"
      ];

      # Configure sandbox overrides for application access.
      overrides = {
        # Grants Obsidian access to system fonts and the Nix store.
        "md.obsidian.Obsidian" = {
          Context = {
            filesystems = [
              "~/.nix-profile/share/fonts:ro"
              "/nix/store:ro"
            ];
          };
        };

        # Unlocks font access for all Flatpak applications to ensure proper rendering.
        "*" = {
          Context = {
            filesystems = [
              "~/.local/share/fonts:ro"
              "~/.fonts:ro"
              "/usr/share/fonts:ro"
              "/usr/local/share/fonts:ro"
              "/nix/store:ro"
              "/nix/var/nix/profiles/default/share/fonts:ro"
              "~/.nix-profile/share/fonts:ro"
              "xdg-config/fontconfig:ro"
            ];
          };
        };
      };
    };
  };
}
