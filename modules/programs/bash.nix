{ ... }:

{
  programs.bash = {
    enable = true;
    shellAliases = {
      ls  = "eza";
      cat = "bat";
      grep = "rg";
    };
    initExtra = ''
      export PATH="$HOME/.nix-profile/bin:$PATH"
    '';
  };
}
