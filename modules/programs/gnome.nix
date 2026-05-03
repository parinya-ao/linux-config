{ ... }:

{
  dconf.settings = {
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = 200;
      repeat-interval = 30;
    };
    
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
    };

    "org/gnome/desktop/interface" = {
      show-battery-percentage = true;
      clock-show-date = true;
    };
  };
}
