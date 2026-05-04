# ═══════════════════════════════════════════════════════════════════════════════
#
#  Pure GNOME — Maximum Stability Configuration
#  Target  : Fedora 44 · GNOME 50.1 · Mutter (Wayland) · No Extensions
#  Author  : Home-Manager dconf module
#  Purpose : Minimal, macOS-philosophy GNOME — clean, fast, predictable
#
# ───────────────────────────────────────────────────────────────────────────────
#  BUG ROOT CAUSE (Windows seemingly disappear on Super key press):
#    Previously, num-workspaces = 6 caused the Activities Overview to display
#    6 workspace thumbnails. Pressing Super made windows appear lost because
#    they remained on workspace 1 while the overview showed all workspaces.
#    FIX: Set num-workspaces = 1 and dynamic-workspaces = false.
#         All windows are constrained to a single workspace, preventing
#         them from being misplaced.
#
#  DESIGN PHILOSOPHY:
#    • Pure Adwaita: Zero extensions.
#    • Single workspace: macOS-like behavior (no Spaces unless Mission Control is used).
#    • Wayland-native: Utilizes portal/compositor APIs, avoiding X11 workarounds.
#    • Windows-compatible shortcuts: Preserves muscle memory.
#    • Right-aligned window controls: appmenu, minimize, maximize, close.
#
# ═══════════════════════════════════════════════════════════════════════════════

{ lib, pkgs, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {

    # ════════════════════════════════════════════════════════════════════════════
    #  §0  GNOME SHELL — Pure, Zero Extension
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  disable-user-extensions = true  → Blocks ALL extensions, regardless of installation status.
    #  enabled-extensions = []         → Explicitly empty list for clarity.
    #  welcome-dialog-last-shown-version → Suppresses the first-run welcome dialog.
    #
    "org/gnome/shell" = {
      disable-user-extensions           = true;
      enabled-extensions                = [];
      welcome-dialog-last-shown-version = "9999.0";

      # App picker / Favorites: Apps pinned to the dock (adjust as needed).
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Console.desktop"
      ];
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §1  INTERFACE & THEMING — Adwaita Pure Dark
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  Theming Rationale:
    #    • Custom GTK themes often cause instability during GNOME updates.
    #    • Adwaita is rigorously tested every release.
    #    • Dark mode combined with a teal accent provides a polished aesthetic
    #      without requiring extensions.
    #
    "org/gnome/desktop/interface" = {
      color-scheme            = "prefer-dark";       # Adwaita Dark.
      accent-color            = "teal";              # GNOME 47+ accent color.
      gtk-theme               = "Adwaita";           # Strictly Adwaita to prevent UI crashes.
      icon-theme              = "Adwaita";
      cursor-theme            = "Adwaita";
      cursor-size             = 24;

      # Top bar clock configuration.
      clock-show-date         = true;
      clock-show-weekday      = true;
      clock-format            = "24h";               # Change to "12h" if preferred.

      # Battery display.
      show-battery-percentage = true;

      # Font rendering: Optimized for 2880x1800 HiDPI displays (e.g., Acer Swift SFG14-71).
      font-antialiasing       = "rgba";              # Subpixel antialiasing.
      font-hinting            = "slight";            # Optimal for HiDPI displays.
      text-scaling-factor     = 1.0;

      # Animations: Enabled to improve spatial awareness.
      enable-animations       = true;

      # Toolkit backend behavior.
      gtk-enable-primary-paste = false;              # Disables middle-click paste to prevent accidental inputs.
      enable-hot-corners      = true;                # Enables the top-left hot corner for the Activities Overview.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §2  WINDOW MANAGER PREFERENCES
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  KEY FIX: num-workspaces = 1 constrains all windows to a single workspace.
    #    Pressing Super displays all active windows in the Overview, eliminating
    #    the risk of losing track of windows across multiple workspaces.
    #
    #  Button layout configuration:
    #    appmenu (left)  : Application menu icon on the far left.
    #    minimize        : 1st button on the right.
    #    maximize        : 2nd button on the right.
    #    close           : 3rd button on the right.
    #
    "org/gnome/desktop/wm/preferences" = {
      button-layout                = "appmenu:minimize,maximize,close";
      focus-mode                   = "click";        # Windows/macOS-style click-to-focus behavior.
      auto-raise                   = false;
      num-workspaces               = 1;              # ★ SINGLE WORKSPACE FIX
      action-double-click-titlebar = "toggle-maximize";
      action-middle-click-titlebar = "lower";
      action-right-click-titlebar  = "menu";
      resize-with-right-button     = false;          # Disables meta+right-click window resizing.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §3  MUTTER — Wayland Compositor
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  dynamic-workspaces = false:
    #    → Prevents GNOME from automatically creating or removing workspaces.
    #    → Enforces a strict single-workspace environment.
    #
    #  scale-monitor-framebuffer:
    #    → Enables fractional scaling for high-resolution displays (e.g., 2880x1800).
    #    → Provides Wayland-native scaling, avoiding blurry Xwayland upscaling.
    #    → Marked as experimental but stable on GNOME 45+ with Intel Xe graphics.
    #
    "org/gnome/mutter" = {
      dynamic-workspaces         = false;            # ★ Disables dynamic workspaces (locks to 1).
      workspaces-only-on-primary = true;
      edge-tiling                = true;             # Snaps windows to screen edges.
      experimental-features      = [ "scale-monitor-framebuffer" ];

      # Centered new windows (macOS-like behavior).
      center-new-windows         = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §4  KEYBOARD & INPUT SOURCES
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/peripherals/keyboard" = {
      delay           = mkUint32 180;  # 180ms delay before key repeat initiates.
      repeat-interval = mkUint32 25;   # 25ms interval between repeats (~40 chars/sec).
    };

    "org/gnome/desktop/input-sources" = {
      sources     = [
        (mkTuple [ "xkb" "us" ])       # English (US).
        (mkTuple [ "xkb" "th" ])       # Thai.
      ];
      mru-sources = [
        (mkTuple [ "xkb" "us" ])
        (mkTuple [ "xkb" "th" ])
      ];
      xkb-options = [
        "grp:caps_toggle"              # Toggles layout using CapsLock.
        "terminate:ctrl_alt_bksp"      # Kills the X/Wayland session with Ctrl+Alt+Backspace.
      ];
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §5  TOUCHPAD & MOUSE
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/peripherals/touchpad" = {
      click-method                 = "areas";        # Physical Left/Right click zones.
      two-finger-scrolling-enabled = true;
      tap-to-click                 = true;
      natural-scroll               = true;           # macOS-style natural scrolling (content follows finger).
      speed                        = 0.3;
      disable-while-typing         = true;           # Prevents accidental taps while typing.
      tap-and-drag                 = true;           # Tap once, then drag to select/move.
      tap-and-drag-lock            = false;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      natural-scroll = false;                        # Traditional mouse scrolling (scroll wheel up = content moves up).
      speed          = 0.0;
      accel-profile  = "default";
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §6  KEYBINDINGS
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  KEYBINDING PHILOSOPHY:
    #    • Exclusively use Wayland-native mechanisms (no X11 fallback tools).
    #    • Retain Windows-compatible muscle memory (e.g., Alt+F4, Super+D, Super+Shift+S).
    #    • Provide macOS-compatible alternatives (e.g., Super+Q, Super+H).
    #    • Remove all workspace-switching shortcuts (irrelevant in a single-workspace setup).
    #
    # ─────────────────────────────────────────────────────────────────────────
    #  §6.1  Custom Keybindings (External Commands)
    # ─────────────────────────────────────────────────────────────────────────

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];

      # ★ Screenshot Portal: Utilizes the Wayland-native GNOME 42+ built-in
      #   screenshot UI instead of the legacy 'gnome-screenshot' tool.
      #   Mapping is handled in §6.3 via 'org/gnome/shell/keybindings'.
      #   These legacy keys are cleared to prevent conflicts.
      screenshot      = [];
      area-screenshot = [];
    };

    # Terminal: Ctrl+Alt+T (universal standard).
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name    = "Terminal (Ghostty)";
      command = "ghostty";
      binding = "<Control><Alt>t";
    };

    # Files: Super+E (Windows Explorer style).
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name    = "Files (Nautilus)";
      command = "nautilus --new-window";
      binding = "<Super>e";
    };

    # ─────────────────────────────────────────────────────────────────────────
    #  §6.2  Window Manager Keybindings
    # ─────────────────────────────────────────────────────────────────────────

    "org/gnome/desktop/wm/keybindings" = {

      # ── Window Control ──────────────────────────────────────────────────────
      close             = [ "<Super>q" "<Alt>F4" ];  # Super+Q (macOS) and Alt+F4 (Windows).
      maximize          = [ "<Super>Up" ];           # Windows-style: Snap top / Maximize.
      unmaximize        = [ "<Super>Down" ];         # Windows-style: Restore down / Unmaximize.
      toggle-fullscreen = [ "<Super>f" "F11" ];      # F11 (Universal) and Super+F.
      minimize          = [ "<Super>h" ];            # macOS-style: Hide/Minimize.

      # Window Tiling: Windows 11 snap style.
      tile-left  = [ "<Super>Left" ];
      tile-right = [ "<Super>Right" ];

      # Show Desktop: Super+D (Windows) / F11 (macOS).
      show-desktop = [ "<Super>d" ];

      # Moves windows between active monitors.
      move-to-monitor-left  = [ "<Super><Shift>Left" ];
      move-to-monitor-right = [ "<Super><Shift>Right" ];
      move-to-monitor-up    = [ "<Super><Shift>Up" ];
      move-to-monitor-down  = [ "<Super><Shift>Down" ];

      # Application and Window Switching.
      switch-applications          = [ "<Super>Tab" ];
      switch-applications-backward = [ "<Super><Shift>Tab" ];
      switch-windows               = [ "<Alt>Tab" ];
      switch-windows-backward      = [ "<Alt><Shift>Tab" ];

      # Cycles through windows of the same application class (e.g., multiple Firefox instances).
      cycle-windows          = [ "<Super>grave" ];   # Super+Grave (Backtick).
      cycle-windows-backward = [ "<Super><Shift>grave" ];

      # ── Workspace Switching (Cleared for single workspace setup) ────────────
      switch-to-workspace-1    = [];
      switch-to-workspace-2    = [];
      switch-to-workspace-3    = [];
      switch-to-workspace-4    = [];
      switch-to-workspace-5    = [];
      switch-to-workspace-6    = [];
      switch-to-workspace-last = [];
      switch-to-workspace-left = [];
      switch-to-workspace-right= [];
      switch-to-workspace-up   = [];
      switch-to-workspace-down = [];

      move-to-workspace-1      = [];
      move-to-workspace-2      = [];
      move-to-workspace-3      = [];
      move-to-workspace-4      = [];
      move-to-workspace-5      = [];
      move-to-workspace-6      = [];
      move-to-workspace-last   = [];
      move-to-workspace-left   = [];
      move-to-workspace-right  = [];
      move-to-workspace-up     = [];
      move-to-workspace-down   = [];

      # ── Miscellaneous ───────────────────────────────────────────────────────
      panel-main-menu    = [];                       # Disables Super+F1 to prevent overlap.
      panel-run-dialog   = [ "<Alt>F2" ];            # Alt+F2: Run command dialog.
      begin-move         = [ "<Alt>F7" ];            # Initiates window movement via keyboard.
      begin-resize       = [ "<Alt>F8" ];            # Initiates window resizing via keyboard.
    };

    # ─────────────────────────────────────────────────────────────────────────
    #  §6.3  GNOME Shell Keybindings
    #        (Overview, Screenshot Portal, App Grid)
    # ─────────────────────────────────────────────────────────────────────────
    #
    #  ★ SUPER KEY BEHAVIOR:
    #    Pressing Super triggers the Activities Overview (hardcoded in GNOME,
    #    requires extensions to remap). In a single-workspace setup, this safely
    #    displays all open windows at a glance without the risk of losing them
    #    across virtual desktops.
    #
    #  ★ SCREENSHOT UI:
    #    Triggers the GNOME 42+ interactive screenshot portal. Fully Wayland-native,
    #    bypassing legacy X11-based tools. Supports screen recording, region
    #    selection, and window capture.
    #
    "org/gnome/shell/keybindings" = {
      # Windows-style screenshot trigger: Super+Shift+S.
      show-screenshot-ui        = [ "<Super><Shift>s" ];

      # Application Grid: Super+A or double-tap Super.
      toggle-application-view   = [ "<Super>a" ];

      # Notification panel focus.
      focus-active-notification = [ "<Super>n" ];

      # Disables unnecessary shortcuts to prevent conflicts.
      toggle-message-tray       = [];
      open-new-window-shortcut-0= [];
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §7  POWER MANAGEMENT
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action            = "nothing";    # Disables power button action to prevent accidental suspension.
      sleep-inactive-ac-timeout      = 3600;         # Suspends after 1 hour of inactivity on AC power.
      sleep-inactive-ac-type         = "suspend";
      sleep-inactive-battery-timeout = 900;          # Suspends after 15 minutes of inactivity on battery power.
      sleep-inactive-battery-type    = "suspend";
      ambient-enabled                = false;        # Disables ambient light sensor for consistent brightness.
    };

    # Screen blanking intervals.
    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 600;                     # Blanks screen after 10 minutes of inactivity.
    };

    # Screen locking policies.
    "org/gnome/desktop/screensaver" = {
      lock-enabled        = true;
      lock-delay          = mkUint32 60;             # Locks screen 1 minute after screen blanking.
      user-switch-enabled = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §8  NIGHT LIGHT
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled            = true;
      night-light-temperature        = mkUint32 3700; # Warm white color temperature (adjustable between 2700K and 6500K).
      night-light-schedule-automatic = true;          # Automatically schedules based on local sunset/sunrise times.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §9  PRIVACY & TELEMETRY
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/privacy" = {
      report-technical-problems = false;             # Disables automatic crash reporting.
      send-software-usage-stats = false;             # Disables telemetry and software usage statistics.
      remove-old-temp-files     = true;
      remove-old-trash-files    = true;
      old-files-age             = mkUint32 7;        # Purges files older than 7 days.
      remember-recent-files     = true;
      recent-files-max-age      = 30;                # Retains recent files history for 30 days.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §10  NOTIFICATIONS
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/notifications" = {
      show-banners        = true;                    # Enables notification banners (set to false for persistent Do Not Disturb).
      show-in-lock-screen = false;                   # Hides notifications on the lock screen for privacy.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §11  NAUTILUS — File Manager
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer   = "list-view";
      show-hidden-files       = false;
      show-create-link        = true;
      show-delete-permanently = true;                # Enables permanent deletion via Shift+Delete.
      recursive-search        = "local-only";
    };

    "org/gnome/nautilus/list-view" = {
      default-zoom-level      = "small";
      use-tree-view           = true;                # Enables inline folder expansion in list view.
      default-column-order    = [ "name" "size" "type" "date_modified" ];
      default-visible-columns = [ "name" "size" "date_modified" ];
    };

    "org/gnome/nautilus/icon-view" = {
      default-zoom-level = "medium";
    };

    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden            = false;
      sort-directories-first = true;
      show-size-column       = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §12  TEXT EDITOR (GNOME Text Editor)
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/TextEditor" = {
      highlight-current-line = true;
      show-line-numbers      = true;
      show-map               = false;
      indent-style           = "space";
      tab-width              = mkUint32 4;
      use-system-font        = true;
      restore-session        = false;                # Disables session restoration for a clean slate on launch (improves stability).
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §13  CALENDAR & CLOCK
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/calendar" = {
      show-weekdate = true;                          # Displays week numbers in the calendar.
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §14  LOCATION
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  Required for automatic Night Light scheduling.
    #
    "org/gnome/system/location" = {
      enabled = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §15  TWEAKS COMPATIBILITY
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/tweaks" = {
      show-extensions-notice = false;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §16  WELLBEING / BREAK REMINDERS
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/break-reminders/movement" = {
      duration-seconds = mkUint32 300;               # 5-minute break duration.
      interval-seconds = mkUint32 1800;              # Triggers every 30 minutes.
      play-sound       = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §17  DISPLAY & FRACTIONAL SCALING
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  NOTE: Resolution, refresh rate, and display scaling are best managed via
    #  the GNOME Settings UI rather than dconf. Monitor-specific configurations
    #  rely on EDID hashes, which are historically volatile in declarative Nix setups.
    #
    #  For a 2880x1800 display (e.g., Swift SFG14-71), 200% integer scaling is
    #  recommended via Settings. For fractional scaling (e.g., 175%), the
    #  'scale-monitor-framebuffer' experimental feature is already enabled in §3,
    #  allowing configuration directly through Settings > Displays > Scale.

  };
}
