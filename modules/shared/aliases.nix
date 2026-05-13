{
  # --- Navigation (with zoxide) ---
  cd = "z";
  ".." = "z ..";
  "..." = "z ../..";
  ".4" = "z ../../..";

  # --- File tools ---
  ls = "eza --icons=auto --group-directories-first";
  ll = "eza -lhF --icons=auto --git --group-directories-first";
  la = "eza -lahF --icons=auto --git";
  lt = "eza --tree --level=2 --icons=auto";
  cat = "bat --style=full";
  find = "fd";
  grep = "rg --smart-case";
  sed = "sd";
  awk = "choose";
  cut = "choose";
  diff = "delta";
  man = "batman";
  tree = "eza --tree";
  curl = "xh";

  # --- System ---
  df = "duf";
  du = "dust";
  ps = "procs";
  top = "btm";
  htop = "btm";
  ping = "gping";
}
