{ ... }:

{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -gx PATH $HOME/.nix-profile/bin $PATH
    '';
shellAliases = {
      ls  = "lsd";
      lsl = "lsd -lh";
      lsa = "lsd -A";
      cat = "bat";
      find = "fd";
      grep = "rg";
      
      # --- System Aliases ---
      cp = "cp -v";
      mv = "mv -v";
      rm = "rm -v";
      df = "df -h";
      du = "du -h";
      free = "free -h";
      disk = "lsblk";
      
      # --- Git Aliases ---
      ga = "git add";
      gaa = "git add .";
      gc = "git commit";
      gcm = "git commit -m";
      gst = "git status";
      gb = "git branch";
      gch = "git checkout";
      gp = "git push";
      gpl = "git pull";
      glog = "git log --oneline -10";
      
      # --- Navigation ---
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    # settings = { ... }; 
  };
}
