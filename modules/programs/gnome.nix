# Configuration for GNOME desktop environment via dconf.
# This module integrates custom UI preferences, keybindings, and accessibility settings.

{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {

    # Configures the Ptyxis terminal emulator preferences and default profiles.
    "org/gnome/Ptyxis" = {
      default-profile-uuid = "560e11fc8d73a2613071266869f6b322";
      profile-uuids = [ "560e11fc8d73a2613071266869f6b322" ];
    };

    # Configures general desktop interface behavior, theming, clock, and disables animations.
    "org/gnome/desktop/interface" = {
      accent-color = "teal";
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
      toolkit-accessibility = false;
      clock-show-date = true;
      clock-show-weekday = true;
      enable-animations = false;
    };

    # Defines the order and presence of window control buttons.
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    # Configures physical keyboard behavior, repeat delay, and interval.
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = 200;
      repeat-interval = 30;
    };

    # Configures input sources, language switching, and maps Caps Lock to toggle languages.
    "org/gnome/desktop/input-sources" = {
      sources = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "th" ]) ];
      mru-sources = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "th" ]) ];
      xkb-options = [ "grp:caps_toggle" ];
    };

    # Configures touchpad gestures, click areas, and scrolling.
    "org/gnome/desktop/peripherals/touchpad" = {
      click-method = "areas";
      two-finger-scrolling-enabled = true;
    };

    # Registers a list of custom keybinding paths.
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    # Defines the specific shortcut to launch the Ghostty terminal via Ctrl+Alt+T.
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "ghostty";
      command = "ghostty";
      binding = "<Control><Alt>t";
    };

    # Disables action on physical power button press to prevent accidental shutdown.
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "nothing";
    };

    # Activates the Night Light feature to reduce blue light.
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
    };

    # Limits UI motion effects to assist users with motion sensitivity.
    "org/gnome/desktop/a11y/interface" = {
      reduced-motion = "reduce";
    };

    # Configures screen magnifier crosshairs.
    "org/gnome/desktop/a11y/magnifier" = {
      cross-hairs-length = 58;
    };

    # Enables audio alerts for eyesight break reminders.
    "org/gnome/desktop/break-reminders/eyesight" = {
      play-sound = true;
    };

    # Requires a 5-minute physical movement break every 30 minutes with audio alerts.
    "org/gnome/desktop/break-reminders/movement" = {
      duration-seconds = mkUint32 300;
      interval-seconds = mkUint32 1800;
      play-sound = true;
    };

    # Caps daily screen time at 8 hours.
    "org/gnome/desktop/screen-time-limits" = {
      daily-limit-seconds = mkUint32 28800;
    };

    # Configures the layout and main directory categories of application folders.
    "org/gnome/desktop/app-folders" = {
      folder-children = [ "System" "Utilities" "YaST" "Pardus" ];
    };

    # Configures the 'System' application folder.
    "org/gnome/desktop/app-folders/folders/System" = {
      name = "X-GNOME-Shell-System.directory";
      translate = true;
      apps = [
        "org.gnome.baobab.desktop"
        "org.gnome.DiskUtility.desktop"
        "org.gnome.Logs.desktop"
        "org.freedesktop.MalcontentControl.desktop"
        "org.gnome.SystemMonitor.desktop"
      ];
    };

    # Configures the 'Utilities' application folder.
    "org/gnome/desktop/app-folders/folders/Utilities" = {
      name = "X-GNOME-Shell-Utilities.directory";
      translate = true;
      apps = [
        "org.gnome.Decibels.desktop"
        "org.gnome.Connections.desktop"
        "org.gnome.Papers.desktop"
        "org.gnome.font-viewer.desktop"
        "org.gnome.Loupe.desktop"
      ];
    };

    # Configures the 'YaST' application folder for SUSE tools.
    "org/gnome/desktop/app-folders/folders/YaST" = {
      name = "suse-yast.directory";
      translate = true;
      categories = [ "X-SuSE-YaST" ];
    };

    # Configures the 'Pardus' application folder.
    "org/gnome/desktop/app-folders/folders/Pardus" = {
      name = "X-Pardus-Apps.directory";
      translate = true;
      categories = [ "X-Pardus-Apps" ];
    };

    # Disables popup notification banners for a distraction-free environment.
    "org/gnome/desktop/notifications" = {
      show-banners = false;
    };

    # Defines the priority order of GNOME Shell search results.
    "org/gnome/desktop/search-providers" = {
      sort-order = [
        "org.gnome.Settings.desktop"
        "org.gnome.Contacts.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };

    # Configures biometric fingerprint login at the GDM login screen.
    "org/gnome/login-screen" = {
      enable-fingerprint-authentication = true;
      enable-smartcard-authentication = false;
      enable-switchable-authentication = false;
    };

    # Permits applications to request geographical location data.
    "org/gnome/system/location" = {
      enabled = true;
    };

    # Suppresses the warning notice about third-party extensions in GNOME Tweaks.
    "org/gnome/tweaks" = {
      show-extensions-notice = false;
    };

    # Configures the standard GTK4 file picker dialog behavior.
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = false;
      sort-directories-first = false;
    };

  };
}
