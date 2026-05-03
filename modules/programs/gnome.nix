{ lib, pkgs, ... }:

with lib.hm.gvariant;

{
  # Install GNOME extensions declaratively
  home.packages = with pkgs.gnomeExtensions; [
    blur-my-shell
    caffeine
    just-perfection
    dash-to-dock
    appindicator        # system tray icons
    vitals              # CPU/RAM/temp in top bar
    paperwm             # tiling WM inside GNOME
    rounded-window-corners-reborn
  ];

  dconf.settings = {

    # ── Extensions ──────────────────────────────────────────
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "blur-my-shell@aunetx"
        "caffeine@patapon.info"
        "just-perfection-desktop@just-perfection"
        "dash-to-dock@micxgx.gmail.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gsconnect@andyholmes.github.io"
        "Vitals@CoreCoding.com"
        "paperwm@paperwm.github.com"
        "rounded-window-corners@fxgn"
      ];
    };

    # Blur My Shell: frosted-glass effect
    "org/gnome/shell/extensions/blur-my-shell" = {
      brightness    = 0.75;
      noise-amount  = 0;
    };
    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      blur           = true;
      brightness     = 0.6;
      sigma          = 30;
    };
    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      blur     = true;
      pipeline = "pipeline_default_rounded";
    };

    # Just Perfection: hide noise, clean layout
    "org/gnome/shell/extensions/just-perfection" = {
      activities-button     = false;   # hide Activities button
      app-menu              = false;
      panel-notification-icon = false;
      search                = false;   # faster overview
      animation             = 2;       # faster animations (1=disable,2=faster,3=normal)
      workspace-popup       = false;
      window-demands-attention-focus = true;
    };

    # Dash to Dock: macOS-style dock
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position         = "BOTTOM";
      intellihide           = true;
      intellihide-mode      = "FOCUS_APPLICATION_WINDOWS";
      autohide              = true;
      animation-time        = 0.15;
      show-trash            = false;
      show-mounts           = false;
      custom-theme-shrink   = true;
      dash-max-icon-size    = 36;
    };

    # Vitals: top-bar monitoring
    "org/gnome/shell/extensions/vitals" = {
      show-temperature = true;
      show-memory      = true;
      show-processor   = true;
      show-network     = true;
      show-storage     = false;
      hot-sensors      = [ "_processor_usage_" "_memory_usage_" ];
    };

    # ── Interface ────────────────────────────────────────────
    "org/gnome/desktop/interface" = {
      accent-color          = "teal";
      color-scheme          = "prefer-dark";
      show-battery-percentage = true;
      clock-show-date        = true;
      clock-show-weekday     = true;
      enable-animations      = true;   # let extensions handle animation speed
      font-antialiasing      = "rgba";
      font-hinting           = "slight";
      text-scaling-factor    = 1.0;
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout       = "appmenu:minimize,maximize,close";
      focus-mode          = "mouse";     # sloppy focus like tiling WMs
      auto-raise          = false;
      num-workspaces      = 6;
    };

    # Dynamic workspaces + multi-monitor
    "org/gnome/mutter" = {
      dynamic-workspaces        = false;  # fixed 6 workspaces
      workspaces-only-on-primary = true;
      edge-tiling               = true;
      experimental-features     = [ "scale-monitor-framebuffer" ]; # HiDPI
    };

    # ── Input ────────────────────────────────────────────────
    "org/gnome/desktop/peripherals/keyboard" = {
      delay           = 180;
      repeat-interval = 25;
    };

    "org/gnome/desktop/input-sources" = {
      sources     = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "th" ]) ];
      mru-sources = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "th" ]) ];
      xkb-options = [ "grp:caps_toggle" "terminate:ctrl_alt_bksp" ];
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      click-method             = "areas";
      two-finger-scrolling-enabled = true;
      tap-to-click             = true;
      natural-scroll           = true;
      speed                    = 0.3;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      natural-scroll = false;
      speed          = 0.0;
    };

    # ── Keybindings ──────────────────────────────────────────
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name    = "Terminal (Ghostty)";
      command = "ghostty";
      binding = "<Control><Alt>t";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name    = "Files";
      command = "nautilus";
      binding = "<Super>e";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      name    = "Screenshot (Area)";
      command = "gnome-screenshot -a -c";
      binding = "<Shift><Super>s";
    };

    # WM workspace shortcuts (Super+1..6)
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      move-to-workspace-1   = [ "<Super><Shift>1" ];
      move-to-workspace-2   = [ "<Super><Shift>2" ];
      move-to-workspace-3   = [ "<Super><Shift>3" ];
      move-to-workspace-4   = [ "<Super><Shift>4" ];
      move-to-workspace-5   = [ "<Super><Shift>5" ];
      move-to-workspace-6   = [ "<Super><Shift>6" ];
      close                 = [ "<Super>q" ];
      maximize              = [ "<Super>m" ];
      toggle-fullscreen     = [ "<Super>f" ];
    };

    # ── System / Power ───────────────────────────────────────
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action       = "nothing";
      sleep-inactive-ac-timeout = 3600;
      sleep-inactive-ac-type    = "suspend";
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled     = true;
      night-light-temperature = mkUint32 3700;
      night-light-schedule-automatic = true;
    };

    # ── Health / Wellness ────────────────────────────────────
    "org/gnome/desktop/break-reminders/eyesight" = {
      play-sound = true;
    };

    "org/gnome/desktop/break-reminders/movement" = {
      duration-seconds = mkUint32 300;
      interval-seconds = mkUint32 1800;
      play-sound       = true;
    };

    "org/gnome/desktop/screen-time-limits" = {
      daily-limit-seconds = mkUint32 28800;
    };

    # ── A11y / Accessibility ─────────────────────────────────
    "org/gnome/desktop/a11y/interface" = {
      reduced-motion = "reduce";
    };

    "org/gnome/desktop/a11y/magnifier" = {
      cross-hairs-length = 58;
    };

    # ── Notifications ────────────────────────────────────────
    "org/gnome/desktop/notifications" = {
      show-banners      = false;
      show-in-lock-screen = false;
    };

    # ── Privacy ──────────────────────────────────────────────
    "org/gnome/desktop/privacy" = {
      report-technical-problems   = false;
      send-software-usage-stats   = false;
      remove-old-temp-files       = true;
      remove-old-trash-files      = true;
      old-files-age               = mkUint32 7;
    };

    # ── Search & Files ───────────────────────────────────────
    "org/gnome/desktop/search-providers" = {
      sort-order = [
        "org.gnome.Settings.desktop"
        "org.gnome.Contacts.desktop"
        "org.gnome.Nautilus.desktop"
      ];
      disabled = [
        "org.gnome.Terminal.desktop"
      ];
    };

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer   = "list-view";
      show-hidden-files        = false;
      show-create-link         = true;
      show-delete-permanently  = true;
    };

    # ── App Folders ──────────────────────────────────────────
    "org/gnome/desktop/app-folders" = {
      folder-children = [ "System" "Utilities" "YaST" "Pardus" ];
    };

    "org/gnome/desktop/app-folders/folders/System" = {
      name      = "X-GNOME-Shell-System.directory";
      translate = true;
      apps = [
        "org.gnome.baobab.desktop"
        "org.gnome.DiskUtility.desktop"
        "org.gnome.Logs.desktop"
        "org.freedesktop.MalcontentControl.desktop"
        "org.gnome.SystemMonitor.desktop"
      ];
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      name      = "X-GNOME-Shell-Utilities.directory";
      translate = true;
      apps = [
        "org.gnome.Decibels.desktop"
        "org.gnome.Connections.desktop"
        "org.gnome.Papers.desktop"
        "org.gnome.font-viewer.desktop"
        "org.gnome.Loupe.desktop"
      ];
    };

    "org/gnome/desktop/app-folders/folders/YaST" = {
      name       = "suse-yast.directory";
      translate  = true;
      categories = [ "X-SuSE-YaST" ];
    };

    "org/gnome/desktop/app-folders/folders/Pardus" = {
      name       = "X-Pardus-Apps.directory";
      translate  = true;
      categories = [ "X-Pardus-Apps" ];
    };

    # ── Misc ─────────────────────────────────────────────────
    "org/gnome/system/location"    = { enabled = true; };
    "org/gnome/tweaks"             = { show-extensions-notice = false; };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden              = false;
      sort-directories-first   = true;   # was false — directories first is ♥
    };
  };
}
