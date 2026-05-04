# ═══════════════════════════════════════════════════════════════════════════════
#
#  Pure GNOME — Maximum Stability Configuration
#  Target  : Fedora 44 · GNOME 50.1 · Mutter (Wayland) · No Extensions
#  Author  : Home-Manager dconf module
#  Purpose : Minimal, macOS-philosophy GNOME — clean, fast, predictable
#
# ───────────────────────────────────────────────────────────────────────────────
#  BUG ROOT CAUSE (กด Super แล้ว windows หาย):
#    เดิม num-workspaces = 6  →  Activities Overview แสดง 6 workspace thumbnails
#    กด Super แล้ว window ดูเหมือนหาย เพราะ window อยู่ ws1 แต่เห็น overview
#    FIX: num-workspaces = 1 + dynamic-workspaces = false
#         ทุก window อยู่ workspace เดียว ไม่มีทางหายไปไหนแน่นอน
#
#  DESIGN PHILOSOPHY:
#    • Pure Adwaita — ไม่มี extension แม้แต่ตัวเดียว
#    • Single workspace — เหมือน macOS (ไม่มี Space ถ้าไม่ใช้ Mission Control)
#    • Wayland-native — ใช้ portal/compositor APIs ไม่ใช้ X11 workaround
#    • Windows-compatible shortcuts — muscle memory ไม่สะดุด
#    • 3 window buttons right — minimize, maximize, close (appmenu:min,max,close)
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
    #  disable-user-extensions = true   → block ALL extensions ไม่ว่าจะติดตั้งไว้
    #  enabled-extensions = []          → list ว่างเพิ่มความชัดเจน
    #  welcome-dialog-last-shown-version → suppress first-run dialog (รำคาญมาก)
    #
    "org/gnome/shell" = {
      disable-user-extensions           = true;
      enabled-extensions                = [];
      welcome-dialog-last-shown-version = "9999.0";

      # App picker / Favorites — apps ที่ pin บน dock (ปรับตามต้องการ)
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
    #  ทำไมไม่เปลี่ยน theme:
    #    • Custom GTK themes มักทำให้ crash เมื่อ GNOME อัปเดต
    #    • Adwaita ได้รับการ test ทุก release
    #    • Dark mode + teal accent = ดูดีพอแล้วโดยไม่ต้องพึ่ง extension
    #
    "org/gnome/desktop/interface" = {
      color-scheme            = "prefer-dark";       # Adwaita Dark
      accent-color            = "teal";              # GNOME 47+ accent
      gtk-theme               = "Adwaita";           # ห้าม custom (ทำให้ crash)
      icon-theme              = "Adwaita";
      cursor-theme            = "Adwaita";
      cursor-size             = 24;

      # Top bar clock
      clock-show-date         = true;
      clock-show-weekday      = true;
      clock-format            = "24h";               # เปลี่ยนเป็น "12h" ถ้าต้องการ

      # Battery
      show-battery-percentage = true;

      # Font rendering — optimized for 2880×1800 HiDPI (Swift SFG14-71)
      font-antialiasing       = "rgba";              # subpixel antialiasing
      font-hinting            = "slight";            # ดีที่สุดสำหรับ HiDPI
      text-scaling-factor     = 1.0;

      # Animations — เปิดไว้ช่วย orientation awareness
      enable-animations       = true;

      # Toolkit backend
      gtk-enable-primary-paste = false;              # ปิด middle-click paste (accident-prone)
      enable-hot-corners = true; # enable hot conner
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §2  WINDOW MANAGER PREFERENCES
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  KEY FIX: num-workspaces = 1
    #    ทุก window อยู่ workspace เดียว → กด Super → เห็น windows ทั้งหมดใน Overview
    #    ไม่มีทาง "หาย" ไปอีก workspace
    #
    #  button-layout = "appmenu:minimize,maximize,close"
    #    appmenu (left) : application menu icon ซ้ายสุด
    #    minimize        : ปุ่มที่ 1 ขวา
    #    maximize        : ปุ่มที่ 2 ขวา
    #    close           : ปุ่มที่ 3 ขวา  ← 3 buttons on right ตามที่ต้องการ
    #
    "org/gnome/desktop/wm/preferences" = {
      button-layout                = "appmenu:minimize,maximize,close";
      focus-mode                   = "click";        # click to focus เหมือน Windows/macOS
      auto-raise                   = false;
      num-workspaces               = 1;              # ★ SINGLE WORKSPACE FIX
      action-double-click-titlebar = "toggle-maximize";
      action-middle-click-titlebar = "lower";
      action-right-click-titlebar  = "menu";
      resize-with-right-button     = false;          # ปิด meta+right-click resize
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §3  MUTTER — Wayland Compositor
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  dynamic-workspaces = false
    #    → ห้าม GNOME สร้าง/ลบ workspace อัตโนมัติ
    #    → ยืนยัน 1 workspace ตลอดกาล (ทำงานร่วมกับ num-workspaces = 1)
    #
    #  scale-monitor-framebuffer
    #    → Fractional scaling สำหรับ 2880×1800 display
    #    → Wayland-native (ไม่ต้องใช้ Xwayland scaling ที่ blur)
    #    → เป็น "experimental" แต่ stable ใน GNOME 45+ บน Intel Xe
    #
    "org/gnome/mutter" = {
      dynamic-workspaces         = false;            # ★ ห้าม dynamic (lock 1 ws)
      workspaces-only-on-primary = true;
      edge-tiling                = true;             # snap to screen edges
      experimental-features      = [ "scale-monitor-framebuffer" ];

      # Center new windows (macOS-like behavior)
      center-new-windows         = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §4  KEYBOARD & INPUT SOURCES
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/peripherals/keyboard" = {
      delay           = mkUint32 180;  # 180ms before key repeat starts
      repeat-interval = mkUint32 25;   # 25ms between repeats = ~40 chars/sec
    };

    "org/gnome/desktop/input-sources" = {
      sources     = [
        (mkTuple [ "xkb" "us" ])       # EN กด CapsLock → switch
        (mkTuple [ "xkb" "th" ])       # TH
      ];
      mru-sources = [
        (mkTuple [ "xkb" "us" ])
        (mkTuple [ "xkb" "th" ])
      ];
      xkb-options = [
        "grp:caps_toggle"              # CapsLock = EN/TH toggle
        "terminate:ctrl_alt_bksp"      # Ctrl+Alt+Backspace = kill session
      ];
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §5  TOUCHPAD & MOUSE
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/peripherals/touchpad" = {
      click-method                 = "areas";        # physical L/R click zones
      two-finger-scrolling-enabled = true;
      tap-to-click                 = true;
      natural-scroll               = true;           # macOS-style (content follows finger)
      speed                        = 0.3;
      disable-while-typing         = true;           # ป้องกัน accidental tap ขณะพิมพ์
      tap-and-drag                 = true;           # tap once then drag
      tap-and-drag-lock            = false;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      natural-scroll = false;                        # traditional mouse (scroll up = content up)
      speed          = 0.0;
      accel-profile  = "default";
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §6  KEYBINDINGS
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  PHILOSOPHY:
    #    • ใช้ Wayland-native mechanisms ทั้งหมด (ไม่ใช้ X11 tools)
    #    • Windows-compatible muscle memory (Alt+F4, Super+D, Super+Shift+S)
    #    • macOS-compatible alternatives (Super+Q, Super+H)
    #    • ลบ workspace shortcuts ทิ้งทั้งหมด (single workspace ไม่ต้องการ)
    #
    # ─────────────────────────────────────────────────────────────────────────
    #  §6.1  Custom keybindings (external commands)
    # ─────────────────────────────────────────────────────────────────────────

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];

      # ★ Screenshot — ใช้ GNOME built-in portal แทน gnome-screenshot
      #   GNOME 42+ มี screenshot UI built-in (Wayland-native, ดีกว่า gnome-screenshot)
      #   เราจะ map ใน §6.3 ผ่าน org/gnome/shell/keybindings แทน
      #   ดังนั้น clear key เหล่านี้ออกเพื่อป้องกัน conflict
      screenshot      = [];
      area-screenshot = [];
    };

    # Terminal — Ctrl+Alt+T (universal standard)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name    = "Terminal (Ghostty)";
      command = "ghostty";
      binding = "<Control><Alt>t";
    };

    # Files — Super+E (Windows Explorer style)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name    = "Files (Nautilus)";
      command = "nautilus --new-window";
      binding = "<Super>e";
    };

    # ─────────────────────────────────────────────────────────────────────────
    #  §6.2  Window Manager keybindings
    # ─────────────────────────────────────────────────────────────────────────

    "org/gnome/desktop/wm/keybindings" = {

      # ── Window control ──────────────────────────────────────────────────────
      close             = [ "<Super>q" "<Alt>F4" ];  # Super+Q (macOS) + Alt+F4 (Windows)
      maximize          = [ "<Super>Up" ];            # Windows: snap top
      unmaximize        = [ "<Super>Down" ];          # Windows: restore
      toggle-fullscreen = [ "<Super>f" "F11" ];       # F11 universal + Super+F
      minimize          = [ "<Super>h" ];             # macOS: Command+H = hide

      # Tiling — Windows 11 snap style
      tile-left  = [ "<Super>Left" ];
      tile-right = [ "<Super>Right" ];

      # Show desktop — Windows: Super+D / macOS: F11
      show-desktop = [ "<Super>d" ];

      # Move window between monitors (useful for external display)
      move-to-monitor-left  = [ "<Super><Shift>Left" ];
      move-to-monitor-right = [ "<Super><Shift>Right" ];
      move-to-monitor-up    = [ "<Super><Shift>Up" ];
      move-to-monitor-down  = [ "<Super><Shift>Down" ];

      # App switching
      switch-applications          = [ "<Super>Tab" ];
      switch-applications-backward = [ "<Super><Shift>Tab" ];
      switch-windows               = [ "<Alt>Tab" ];
      switch-windows-backward      = [ "<Alt><Shift>Tab" ];

      # Same-class window cycling (เปิด Firefox หลายหน้าต่าง)
      cycle-windows          = [ "<Super>grave" ];   # Super+` (backtick)
      cycle-windows-backward = [ "<Super><Shift>grave" ];

      # ── Workspace switching — ลบทิ้งทั้งหมด (single workspace) ──────────────
      switch-to-workspace-1    = [];
      switch-to-workspace-2    = [];
      switch-to-workspace-3    = [];
      switch-to-workspace-4    = [];
      switch-to-workspace-5    = [];
      switch-to-workspace-6    = [];
      switch-to-workspace-last = [];
      switch-to-workspace-left  = [];
      switch-to-workspace-right = [];
      switch-to-workspace-up    = [];
      switch-to-workspace-down  = [];

      move-to-workspace-1    = [];
      move-to-workspace-2    = [];
      move-to-workspace-3    = [];
      move-to-workspace-4    = [];
      move-to-workspace-5    = [];
      move-to-workspace-6    = [];
      move-to-workspace-last = [];
      move-to-workspace-left  = [];
      move-to-workspace-right = [];
      move-to-workspace-up    = [];
      move-to-workspace-down  = [];

      # ── Misc ────────────────────────────────────────────────────────────────
      panel-main-menu    = [];                       # ปิด Super+F1 (ซ้อนทับ)
      panel-run-dialog   = [ "<Alt>F2" ];            # Alt+F2 = run command dialog
      begin-move         = [ "<Alt>F7" ];            # move window with keyboard
      begin-resize       = [ "<Alt>F8" ];            # resize with keyboard
    };

    # ─────────────────────────────────────────────────────────────────────────
    #  §6.3  GNOME Shell keybindings
    #        (Overview, Screenshot Portal, App Grid)
    # ─────────────────────────────────────────────────────────────────────────
    #
    #  ★ SUPER KEY BEHAVIOR:
    #    Super alone → Activities Overview (cannot remap without extension)
    #    Overview ใน single workspace = เห็น windows ทั้งหมดอยู่ตรงหน้า
    #    ไม่มีทาง "หาย" แล้ว เพราะมีแค่ workspace เดียว
    #
    #  ★ SCREENSHOT — ใช้ show-screenshot-ui (GNOME 42+ built-in portal)
    #    Wayland-native 100% ไม่ต้องใช้ gnome-screenshot ที่ X11-based
    #    ทำงานกับ screen recording, region selection, window mode
    #
    "org/gnome/shell/keybindings" = {
      # ★ Windows-style screenshot: Super+Shift+S → GNOME Screenshot UI
      show-screenshot-ui     = [ "<Super><Shift>s" ];

      # App grid (ตารางแอป) — Super+A หรือกด Super สองครั้ง
      toggle-application-view = [ "<Super>a" ];

      # Notification panel
      focus-active-notification = [ "<Super>n" ];

      # ปิด shortcut ที่ไม่จำเป็น (ป้องกัน conflict)
      toggle-message-tray = [];
      open-new-window-shortcut-0 = [];
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §7  POWER MANAGEMENT
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action            = "nothing";    # ป้องกัน suspend อุบัติเหตุ
      sleep-inactive-ac-timeout      = 3600;         # 1 ชั่วโมง idle บน AC → suspend
      sleep-inactive-ac-type         = "suspend";
      sleep-inactive-battery-timeout = 900;          # 15 นาที idle บน battery
      sleep-inactive-battery-type    = "suspend";
      ambient-enabled                = false;        # ปิด auto brightness (เสถียรกว่า)
    };

    # Screen blank
    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 600;                     # 10 นาที → screen blank
    };

    # Screen lock
    "org/gnome/desktop/screensaver" = {
      lock-enabled   = true;
      lock-delay     = mkUint32 60;                  # blank 1 นาที → lock
      user-switch-enabled = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §8  NIGHT LIGHT
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled            = true;
      night-light-temperature        = mkUint32 3700; # warm white (ปรับ 2700-6500)
      night-light-schedule-automatic = true;          # ใช้ location-based sunset/sunrise
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §9  PRIVACY & TELEMETRY
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/privacy" = {
      report-technical-problems    = false;           # ไม่ส่ง crash report
      send-software-usage-stats    = false;           # ไม่ส่ง usage stats
      remove-old-temp-files        = true;
      remove-old-trash-files       = true;
      old-files-age                = mkUint32 7;      # ลบหลัง 7 วัน
      remember-recent-files        = true;
      recent-files-max-age         = 30;              # จำ recent files 30 วัน
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §10  NOTIFICATIONS
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/notifications" = {
      show-banners        = true;                    # แสดง popup (เปลี่ยนเป็น false = Do Not Disturb)
      show-in-lock-screen = false;                   # ซ่อน notification บน lock screen
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §11  NAUTILUS — File Manager
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer   = "list-view";
      show-hidden-files       = false;
      show-create-link        = true;
      show-delete-permanently = true;                # shift+delete = permanent delete
      recursive-search        = "local-only";
    };

    "org/gnome/nautilus/list-view" = {
      default-zoom-level = "small";
      use-tree-view      = true;                     # expand folders inline
      default-column-order = [
        "name" "size" "type" "date_modified"
      ];
      default-visible-columns = [
        "name" "size" "date_modified"
      ];
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
      restore-session        = false;                # ไม่ restore เซสชันเก่า (เสถียรกว่า)
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §13  CALENDAR & CLOCK
    # ════════════════════════════════════════════════════════════════════════════

    "org/gnome/desktop/calendar" = {
      show-weekdate = true;                          # แสดงเลขสัปดาห์
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §14  LOCATION (จำเป็นสำหรับ Night Light auto-schedule)
    # ════════════════════════════════════════════════════════════════════════════

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
      duration-seconds = mkUint32 300;               # break 5 นาที
      interval-seconds = mkUint32 1800;              # ทุก 30 นาที
      play-sound       = true;
    };


    # ════════════════════════════════════════════════════════════════════════════
    #  §17  DISPLAY & FRACTIONAL SCALING
    # ════════════════════════════════════════════════════════════════════════════
    #
    #  NOTE: resolution/refresh/scaling จัดการผ่าน GNOME Settings UI แทน dconf
    #  เพราะ monitor-specific config ขึ้นอยู่กับ EDID hash ที่ไม่ stable ใน nix
    #
    #  สำหรับ 2880×1800 Swift SFG14-71 แนะนำ: 200% scaling (2x) ผ่าน Settings
    #  หรือถ้าต้องการ fractional เช่น 175%:
    #    gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
    #    และ set ผ่าน Settings > Displays > Scale
    #
    #  Fractional scaling ถูก enable แล้วใน §3 ผ่าน experimental-features

  };
}
