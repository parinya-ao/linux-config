{ ... }:

{
  programs.git = {
    enable = true;
    signing.format = null; 
    
    settings = {
    alias= {
      amend = "commit --amend --no-edit";
    };
      user = {
        name = "parinya-ao";
        email = "flim.parinya.ao@gmail.com";
      };
      init.defaultBranch = "main";
      
      push.autoSetupRemote = true;
      color.ui = "auto";
      pull.rebase = true;
      rebase.autoStash = true;
      merge.ff = "only";
      
      pack.threads = 0;
      maintenance.auto = true;
      checkout.workers = 0;
      rerere.enabled = true;
      rerere.autoUpdate = true;
    };
  };
}
