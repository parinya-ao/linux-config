{ ... }:

{
  programs.eza = {
    enable = true;
    enableFishIntegration = true; # มันจะสร้าง Alias ls, ll ให้ Fish อัตโนมัติ!
    icons = "auto";               # เปิดโหมดไอคอนสวยๆ
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";          # ตั้งธีมสีให้ bat ได้เลย
    };
  };
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;     # ตัวนี้สาย Nix Dev ต้องมีครับ
  };
}
