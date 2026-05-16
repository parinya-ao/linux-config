# Interactive-only shell aliases.
# IMPORTANT: Never shadow POSIX commands used by system scripts
# (find, sed, awk, grep, curl, cut, man, etc.)

{
  # --- Navigation (with zoxide) ---
  "cd" = "z";
  ".." = "z ..";
  "..." = "z ../..";
  ".4" = "z ../../..";

  # --- Modern CLI tools ---
  "ls" = "eza --icons=auto --group-directories-first";
  "ll" = "eza -lhF --icons=auto --git --group-directories-first";
  "la" = "eza -lahF --icons=auto --git";
  "lt" = "eza --tree --level=2 --icons=auto";
  "cat" = "bat --style=full";
  "tree" = "eza --tree";
  "diff" = "delta";

  # --- Search & Filter (Safe names) ---
  "rg" = "rg --smart-case";
  "fd" = "fd --hidden --follow";

  # --- System ---
  "df" = "duf";
  "du" = "dust";
  "ps" = "procs";
  "top" = "btm";
  "htop" = "btm";
  "ping" = "gping";
}
