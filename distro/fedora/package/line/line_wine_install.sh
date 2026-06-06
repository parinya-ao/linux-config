#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"    # Deep Sky Blue
readonly C_SUCCESS="#04B575"    # Mint Green
readonly C_WARNING="#FFA500"    # Amber
readonly C_DANGER="#FF4500"     # Red-Orange
readonly C_MUTED="#666666"      # Dim Gray
readonly C_ACCENT="#C678DD"     # Soft Purple
readonly C_HIGHLIGHT="#98C379"  # Soft Green

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"
export WINEDEBUG="-fixme"

readonly WINE_PREFIX="$HOME/.wineprefixes/line"
readonly INSTALLER_URL="https://desktop.line-scdn.net/win/new/LineInst.exe"
readonly INSTALLER_PATH="/tmp/LineInst.exe"

# Log file setup
readonly LOG_DIR="$HOME/.local/share/line-wine-install"
readonly LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

AUTO_MODE=false # Default interactive mode
VERBOSE_MODE=false # Default quiet mode
REMOVE_LOGS_AFTER=false   # flag: ลบ log dir หลัง uninstall summary จบ

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────

banner() {
  gum style \
    --border double --border-foreground "$C_PRIMARY" \
    --align center --padding "1 4" --bold \
    "$*"
}

step() {
  gum style --foreground "$C_PRIMARY" --bold "▶  Step ${1}: ${2}"
}

ok() {
  gum style --foreground "$C_SUCCESS" "  ✔  $*"
}

warn() {
  gum style --foreground "$C_WARNING" "  ⚠  $*"
}

fail() {
  local msg="$*"
  # Error box
  gum style \
    --border thick --border-foreground "$C_DANGER" \
    --foreground "$C_DANGER" --bold \
    --padding "0 2" \
    "✖  ERROR: $msg"

  # Context block
  gum style --foreground "$C_WARNING" "━━ CONTEXT ━━"
  kv "Function" "${FUNCNAME[1]}"
  kv "Line" "${BASH_LINENO[0]}"
  kv "Command" "${BASH_COMMAND}"
  kv "Log File" "$LOG_FILE"
  
  log fatal "CRITICAL ERROR" message="$msg" caller="${FUNCNAME[1]}" line="${BASH_LINENO[0]}"
  exit 1
}

info() {
  gum style --foreground "$C_MUTED" "  ℹ  $*"
}

kv() {
  local label value
  label=$(gum style --foreground "$C_MUTED" --width 16 "$1")
  value=$(gum style --foreground "$C_ACCENT" "$2")
  gum join --horizontal "$label" "$value"
}

log() {
  local level="$1"
  local msg="$2"
  shift 2
  gum log --level "$level" --time rfc822 "$msg" "$@" | tee -a "$LOG_FILE" >&2
}

# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────

kill_wine_processes() {
  log info "Cleaning up hung Wine processes"
  pkill -9 -f "wine" 2>/dev/null || true
  pkill -9 -f "wineserver" 2>/dev/null || true
  pkill -9 -f "winedevice" 2>/dev/null || true
  pkill -9 -f "plugplay" 2>/dev/null || true
  sleep 2
}

run_step() {
  local spinner="$1" title="$2"
  shift 2
  
  log info "Starting: $title"
  
  local tmp_out tmp_err
  tmp_out=$(mktemp)
  tmp_err=$(mktemp)
  
  local cmd_status=0
  if [ "$VERBOSE_MODE" = true ]; then
      printf "  \033[38;2;0;191;255m⟫ Executing: %s\033[0m\n" "$*"
     "$@" > "$tmp_out" 2> "$tmp_err" || cmd_status=$?
  else
     gum spin --spinner "$spinner" --title "  ${title}..." -- "$@" > "$tmp_out" 2> "$tmp_err" || cmd_status=$?
  fi
  
  if [ $cmd_status -eq 0 ]; then
    log info "Completed: $title"
    cat "$tmp_out" >> "$LOG_FILE"
    cat "$tmp_err" >> "$LOG_FILE"
    ok "$title"
    rm -f "$tmp_out" "$tmp_err"
  else
    log error "Failed: $title" exit="$cmd_status"
    
    # Show to user
    gum style --foreground "$C_DANGER" "━━ COMMAND OUTPUT ━━"
    cat "$tmp_out"
    gum style --foreground "$C_DANGER" "━━ ERROR OUTPUT ━━"
    cat "$tmp_err"
    
    # Cleanup for fail
    rm -f "$tmp_out" "$tmp_err"
    fail "$title (exit $cmd_status)"
  fi
}

# run_step_optional: เหมือน run_step แต่ไม่ fail ถ้า path ไม่มีหรือ command คืน error
# ใช้สำหรับ uninstall ที่ของอาจไม่มีอยู่แล้ว
run_step_optional() {
  local spinner="$1" title="$2"
  shift 2
  log info "Optional: $title"
  if "$@" >> "$LOG_FILE" 2>&1; then
    ok "$title"
  else
    warn "$title — skipped (not found or already removed)"
    log warn "Optional step skipped" step="$title"
  fi
}

# ── LAYER 3: TASK FUNCTIONS ──────────────────────────────────────────────────

check_dependencies() {
  log debug "Checking dependencies"
  if ! command -v gum >/dev/null 2>&1; then
    echo "Error: 'gum' is not installed. Please install it first."
    exit 1
  fi
  
  local DEPS=("wget" "cabextract" "curl")
  for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      log info "Installing missing dependency" pkg="$dep"
      
      # Verification before install
      if ! dnf repoquery --quiet "$dep" >/dev/null 2>&1; then
          warn "Package '$dep' not found in any enabled repo"
          log warn "Dependency check failed" dep="$dep" repo_check="not_found"
          fail "Package '$dep' not found. Check your repositories."
      fi

      if ! run_step line "Installing $dep" sudo "$PKG_MGR" install -y "$dep"; then
          fail "Failed to install dependency: $dep"
      fi
    fi
  done
  log info "All dependencies verified"
}

detect_os() {
  log debug "Detecting OS"
  if [ -f /etc/fedora-release ]; then
    OS="Fedora"
    PKG_MGR="dnf"
    WINE_DEPS=("wine" "winetricks" "wine-alsa" "wine-pulseaudio" "wine-core")
  else
    local detected="Unknown"
    if [ -f /etc/os-release ]; then
      detected=$(grep -E '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
    fi
    log fatal "Unsupported OS" detected="$detected"
    fail "Unsupported OS: ${detected}. This script supports Fedora only."
  fi
  log info "Detected OS" os="$OS" pkg_mgr="$PKG_MGR"
  info "Detected OS: $OS"
}

detect_session() {
  log debug "Detecting session"
  SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
  WAYLAND_SESSION=false

  if [ "$SESSION_TYPE" = "wayland" ]; then
    WAYLAND_SESSION=true
    log info "Wayland session detected"
    if ! command -v Xwayland >/dev/null 2>&1; then
      log info "Installing Xwayland for Wayland session"
      run_step line "Installing Xwayland" sudo "$PKG_MGR" install -y xorg-x11-server-Xwayland
    else
      log info "Xwayland already installed"
    fi
  else
    log info "Non-Wayland session detected" session="$SESSION_TYPE"
  fi
}

install_wine() {
  step 1 "Installing System Wine & Dependencies"
  log info "Beginning Wine installation"

  run_step line "Installing Wine packages" \
    sudo "$PKG_MGR" install -y "${WINE_DEPS[@]}"
  
  log info "Wine installation complete" version="$(wine --version)"
}

setup_prefix() {
  step 2 "Initializing Wine Prefix (64-bit)"
  log info "Initializing Prefix" path="$WINE_PREFIX"
  
  if [ -d "$WINE_PREFIX" ]; then
    local proceed=false
    if [ "$AUTO_MODE" = true ]; then
      proceed=true
      log info "Auto-mode: Re-initializing existing prefix"
    elif gum confirm "Wine Prefix already exists ($WINE_PREFIX). Re-initialize? (Deletes all LINE data)"; then
      proceed=true
      log info "User confirmed re-initialization"
    fi

    if [ "$proceed" = true ]; then
      run_step monkey "Cleaning old prefix" rm -rf "$WINE_PREFIX"
    else
      log info "Using existing prefix without cleaning"
      info "Using existing prefix"
      return 0
    fi
  fi

  run_step points "Creating Prefix" mkdir -p "$WINE_PREFIX"
  
  # Set Windows 10 version (Required for LINE > 8.3.0)
  run_step pulse "Setting Windows Version to Windows 10" \
    env WINEPREFIX="$WINE_PREFIX" WINEARCH=win64 winecfg /v win10
    
  run_step pulse "Restarting Wine server (clean state)" \
    env WINEPREFIX="$WINE_PREFIX" wineboot -r

  log info "Wine server restarted — prefix ready for installation"
}

install_dependencies() {
  step 3 "Installing Core Windows Components"
  log info "Installing Windows runtimes"
  
  run_step line "Installing corefonts" env WINEPREFIX="$WINE_PREFIX" winetricks -q corefonts
  run_step line "Installing cjkfonts" env WINEPREFIX="$WINE_PREFIX" winetricks -q cjkfonts
  run_step line "Installing vcrun2022" env WINEPREFIX="$WINE_PREFIX" winetricks -q vcrun2022
  run_step line "Installing openal" env WINEPREFIX="$WINE_PREFIX" winetricks -q openal
  run_step line "Installing crypt32" env WINEPREFIX="$WINE_PREFIX" winetricks -q crypt32
  
  log info "Windows components installed"
}

apply_fixes() {
  step 4 "Applying Thai Language & Keyboard Fixes"
  log info "Applying registry fixes"
  
  local reg_file="/tmp/line_fixes.reg"
  cat <<EOF > "$reg_file"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Accessibility\Keyboard Response]
"AutoRepeatDelay"="500"
"AutoRepeatRate"="50"
"BounceTime"="35"
"Flags"="127"
EOF

  run_step dot "Applying Keyboard Debounce Fix" \
    env WINEPREFIX="$WINE_PREFIX" wine regedit "$reg_file"

  log info "Registry fixes applied"
  ok "Fixes applied: Double typing mitigation and performance tuning"
}

install_line() {
  step 5 "Downloading and Installing LINE"
  log info "Downloading installer" url="$INSTALLER_URL"

  local http_code
  http_code=$(curl -o /dev/null --silent --head --write-out "%{http_code}" \
    --connect-timeout 10 --max-time 20 "$INSTALLER_URL")

  case "$http_code" in
    200|301|302)
      log info "Installer URL reachable" http_code="$http_code"
      ;;
    *)
      fail "Installer URL unavailable (HTTP $http_code)."
      ;;
  esac

  run_step globe "Downloading LINE Installer" \
    wget -O "$INSTALLER_PATH" "$INSTALLER_URL"
    
  log info "Launching installer"
  info "Launching LINE Installer — please follow the GUI prompts."
  
  # Retry loop
  local max_retries=2
  local attempt=1
  local success=false

  while [ $attempt -le $max_retries ]; do
      log info "Attempt $attempt of $max_retries to launch installer"
      kill_wine_processes
      
      # Run installer with required deadlock-prevention env vars
      if env WINEPREFIX="$WINE_PREFIX" \
           WINEESYNC=1 \
           WINEFSYNC=1 \
           WINEDLLOVERRIDES="bcrypt,crypt32=n,b" \
           WINEDEBUG="-all" \
           wine "$INSTALLER_PATH"; then
          success=true
          break
      else
          warn "Attempt $attempt failed."
          ((attempt++))
      fi
  done

  if [ "$success" = false ]; then
      fail "Installer failed after $max_retries attempts. Please try to downgrade Wine or run manual cleanup."
  fi
  
  log info "Waiting for installer to finish all background Wine processes"
  sleep 5
  env WINEPREFIX="$WINE_PREFIX" wineserver --wait 2>/dev/null || true
  sleep 3
  log info "Installer session fully settled"
  
  # Verify installation
  local launcher
  launcher=$(find "$WINE_PREFIX/drive_c" -iname "LineLauncher.exe" 2>/dev/null | grep -v "Installer\|Setup\|Inst" | head -1)
  if [[ -z "$launcher" ]]; then
     launcher=$(find "$WINE_PREFIX/drive_c" -iname "LINE.exe" 2>/dev/null | grep -v "Installer\|Setup\|Inst" | head -1)
  fi

  if [[ -z "$launcher" ]]; then
    fail "Installer finished but LINE executable not found. Please ensure the installation completed fully in the GUI."
  fi

  log info "Installer verified" launcher="$launcher"
  # Save path for shortcut creation
  echo "$launcher" > /tmp/line_launcher_path
  
  ok "Installer session finished"
}

create_shortcut() {
  step 6 "Creating Desktop Shortcut"
  log info "Generating .desktop file"
  
  local desktop_file="$HOME/.local/share/applications/line.desktop"
  local launcher_path=""

  # Try to use detected path, fallback to finding it
  if [ -f /tmp/line_launcher_path ]; then
      launcher_path=$(cat /tmp/line_launcher_path)
  fi

  if [[ -z "$launcher_path" ]]; then
      local p1="$WINE_PREFIX/drive_c/users/$USER/AppData/Local/LINE/bin/LineLauncher.exe"
      local p2="$WINE_PREFIX/drive_c/Program Files (x86)/LINE/LineLauncher.exe"
      local p3
      p3=$(find "$WINE_PREFIX/drive_c" -iname "LineLauncher.exe" 2>/dev/null | head -1)
      
      if   [[ -f "$p1" ]]; then launcher_path="$p1"
      elif [[ -f "$p2" ]]; then launcher_path="$p2"
      elif [[ -n "$p3" ]]; then launcher_path="$p3"
      else
        fail "Could not find LineLauncher.exe — installer may not have completed"
      fi
  fi

  log info "Launcher detected" path="$launcher_path"

  local exec_line
  if [ "$WAYLAND_SESSION" = true ]; then
    exec_line="env WINEPREFIX=\"$WINE_PREFIX\" WINEDEBUG=\"-fixme\" QT_QPA_PLATFORM=xcb DISPLAY=:0 XMODIFIERS=\"@im=none\" wine \"$launcher_path\""
  else
    exec_line="env WINEPREFIX=\"$WINE_PREFIX\" WINEDEBUG=\"-fixme\" XMODIFIERS=\"@im=none\" wine \"$launcher_path\""
  fi
  
  mkdir -p "$(dirname "$desktop_file")"
  
  cat <<EOF > "$desktop_file"
[Desktop Entry]
Name=LINE
Exec=$exec_line
Type=Application
Categories=Network;InstantMessaging;
Icon=line
Terminal=false
Comment=LINE Desktop for Linux
EOF

  chmod +x "$desktop_file"
  log info "Shortcut created" path="$desktop_file"
  ok "Shortcut created at $desktop_file"
  info "Environment override: XMODIFIERS=@im=none (Prevents double typing)"
}

show_summary() {
  log info "Showing installation summary"
  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉 LINE INSTALLATION COMPLETE")

  local r1 r2 r3 r4 r5
  r1=$(kv "OS" "$OS")
  r2=$(kv "Prefix" "$WINE_PREFIX")
  r3=$(kv "Architecture" "win64")
  r4=$(kv "Status" "Verified with vcrun2022")
  r5=$(kv "Log File" "$LOG_FILE")

  local hint
  hint=$(gum style --foreground "$C_WARNING" "  ⚠ If Thai characters appear as boxes, set font to 'Tahoma' in LINE settings.")

  local body
  body=$(gum join --vertical --align left \
    "$title" "" "$r1" "$r2" "$r3" "$r4" "$r5" "" "$hint")

  gum style \
    --border rounded --border-foreground "$C_SUCCESS" \
    --padding "1 3" \
    "$body"
}

uninstall_line() {
  banner "🔴  UNINSTALLING LINE — DEEP CLEAN"
  log info "Starting deep uninstallation"

  # ── เลือกระดับการลบ ──────────────────────────────────────────────────────
  local REMOVE_LEVEL
  if [ "$AUTO_MODE" = true ]; then
    REMOVE_LEVEL="LINE only"
    log info "Auto-mode: LINE only removal"
  else
    # แสดง warning box ก่อน
    gum style \
      --border thick --border-foreground "$C_DANGER" \
      --foreground "$C_WARNING" --padding "0 2" \
      "⚠  WARNING: Chat history stored locally WILL BE LOST permanently." \
      "   This action cannot be undone."
    echo ""

    # เลือกระดับการลบ
    REMOVE_LEVEL=$(gum choose \
      --header "Select removal level:" \
      --cursor "▶  " \
      "🟡  LINE only — keep Wine installed" \
      "🔴  LINE + Wine packages — full removal" \
      "❌  Cancel")

    [[ "$REMOVE_LEVEL" == *"Cancel"* ]] && { info "Cancelled."; return 0; }

    # ยืนยันครั้งสุดท้าย
    gum confirm "Are you ABSOLUTELY sure? This cannot be undone." \
      || { info "Aborted."; return 0; }
  fi

  log info "Removal level" level="$REMOVE_LEVEL"

  # ── U-1: Kill Wine/LINE processes ────────────────────────────────────────
  step "U-1" "Killing Wine & LINE processes"
  log info "Killing processes"

  # wineserver -k: หยุด wine server ใน prefix ก่อน
  run_step_optional dot "Stopping Wine server" \
    env WINEPREFIX="$WINE_PREFIX" wineserver -k

  # pkill wine processes ที่อาจค้าง
  run_step_optional dot "Killing residual Wine processes" \
    bash -c 'pkill -9 -f "wine.*[Ll][Ii][Nn][Ee]" 2>/dev/null; pkill -9 -f "wineserver" 2>/dev/null; sleep 1; true'

  log info "Processes killed"

  # ── U-2: ลบ Wine Prefix ──────────────────────────────────────────────────
  step "U-2" "Removing Wine Prefix"
  log info "Removing prefix" path="$WINE_PREFIX"

  if [ -d "$WINE_PREFIX" ]; then
    # วัดขนาดก่อนลบ
    local prefix_size
    prefix_size=$(du -sh "$WINE_PREFIX" 2>/dev/null | cut -f1 || echo "?")
    info "Prefix size: $prefix_size — removing..."
    log info "Prefix size" size="$prefix_size"

    run_step monkey "Removing Wine Prefix [$prefix_size]" \
      rm -rf "$WINE_PREFIX"
    log info "Prefix removed" freed="$prefix_size"
  else
    warn "Wine prefix not found — already removed?"
    log warn "Prefix not found" path="$WINE_PREFIX"
  fi

  # ── U-3: ลบ .desktop shortcuts ───────────────────────────────────────────
  step "U-3" "Removing Desktop Shortcuts"
  log info "Removing .desktop entries"

  # shortcut หลักที่ script สร้าง
  run_step_optional dot \
    "Removing ~/.local/share/applications/line.desktop" \
    rm -f "$HOME/.local/share/applications/line.desktop"

  # .desktop ที่ Wine อาจสร้างเพิ่มเองด้วย wine-menus
  run_step_optional dot \
    "Removing Wine-generated LINE shortcuts" \
    bash -c 'find "$HOME/.local/share/applications" \
      \( -iname "*line*" \) \
      -delete 2>/dev/null; true'

  # shortcut บน ~/Desktop (ถ้าเคย copy ไป)
  run_step_optional dot \
    "Removing ~/Desktop shortcuts" \
    bash -c 'rm -f "$HOME/Desktop/"*[Ll][Ii][Nn][Ee]*.desktop 2>/dev/null; true'

  log info "Desktop shortcuts removed"

  # ── U-4: ลบ Icons ทุก path ───────────────────────────────────────────────
  step "U-4" "Removing LINE Icons"
  log info "Removing icons"

  # ~/.local/share/icons/ — Wine วาง icon hierarchy ที่นี่ตอน register .desktop
  run_step_optional dot \
    "Removing icons from ~/.local/share/icons/" \
    bash -c 'find "$HOME/.local/share/icons" \
      \( -iname "*line*" \) \
      -delete 2>/dev/null; true'

  # hicolor theme — Wine วาง icons ขนาดต่างๆ ที่นี่ (16x16, 32x32, 48x48, 256x256)
  run_step_optional dot \
    "Removing hicolor theme icons" \
    bash -c 'find "$HOME/.local/share/icons/hicolor" \
      \( -iname "*line*" \) \
      -delete 2>/dev/null; true'

  # ~/.local/share/pixmaps/ — บางครั้ง wine copy icon มาที่นี่ด้วย
  run_step_optional dot \
    "Removing pixmaps icons" \
    bash -c 'rm -f "$HOME/.local/share/pixmaps/"*[Ll][Ii][Nn][Ee]* 2>/dev/null; true'

  # ~/.icons/ — user icon theme folder
  run_step_optional dot \
    "Removing ~/.icons/ LINE icons" \
    bash -c 'find "$HOME/.icons" -iname "*line*" -delete 2>/dev/null; true'

  # update icon cache ให้ GNOME/KDE เห็นว่า icon หายไปแล้ว
  run_step_optional dot \
    "Rebuilding icon cache" \
    bash -c '
      gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
      update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
      true
    '

  log info "Icons removed and cache updated"

  # ── U-5: ลบ Temp files ───────────────────────────────────────────────────
  step "U-5" "Cleaning Temp Files"
  log info "Cleaning /tmp"

  run_step_optional dot "Removing /tmp/LineInst.exe" \
    rm -f "$INSTALLER_PATH"

  run_step_optional dot "Removing /tmp/line_fixes.reg" \
    rm -f /tmp/line_fixes.reg

  run_step_optional dot "Removing /tmp/line_launcher_path" \
    rm -f /tmp/line_launcher_path

  run_step_optional dot "Removing Wine .tmp files" \
    bash -c 'rm -f /tmp/.wine-$(id -u)/* 2>/dev/null; true'

  log info "Temp files cleaned"

  # ── U-6: ลบ Winetricks cache (optional) ──────────────────────────────────
  step "U-6" "Winetricks Cache"
  local wtcache="$HOME/.cache/winetricks"

  if [ -d "$wtcache" ]; then
    local wt_size
    wt_size=$(du -sh "$wtcache" 2>/dev/null | cut -f1 || echo "?")
    log info "Winetricks cache found" size="$wt_size"

    local remove_wt=false
    if [ "$AUTO_MODE" = true ]; then
      remove_wt=true
    elif gum confirm "Remove winetricks cache? ($wt_size) — keeping it speeds up future installs"; then
      remove_wt=true
    fi

    if [ "$remove_wt" = true ]; then
      run_step dot "Removing winetricks cache [$wt_size]" rm -rf "$wtcache"
      log info "Winetricks cache removed" freed="$wt_size"
    else
      info "Keeping winetricks cache."
      log info "Winetricks cache kept"
    fi
  else
    info "No winetricks cache — skipping."
    log info "No winetricks cache found"
  fi

  # ── U-7: ลบ Install logs (optional) ──────────────────────────────────────
  step "U-7" "Install Logs"
  log info "Handling install logs" path="$LOG_DIR"

  if [ -d "$LOG_DIR" ]; then
    local log_size
    log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1 || echo "?")

    local remove_logs=false
    if [ "$AUTO_MODE" = false ]; then
      gum confirm "Remove install logs? ($log_size at $LOG_DIR)" && remove_logs=true || true
    fi

    if [ "$remove_logs" = true ]; then
      # ลบทุก log ยกเว้น current log file (ยังเขียนอยู่)
      # ลบ dir ตอนสุดท้ายหลัง summary
      find "$LOG_DIR" -name "*.log" ! -name "$(basename "$LOG_FILE")" \
        -delete 2>/dev/null || true
      log info "Old logs removed — current log will be removed after summary"
      # set flag เพื่อลบ dir ตอนท้าย
      REMOVE_LOGS_AFTER=true
    else
      info "Keeping install logs at $LOG_DIR"
      log info "Logs kept"
    fi
  fi

  # ── U-8: ลบ Wine system packages (ถ้าเลือก full removal) ────────────────
  if [[ "$REMOVE_LEVEL" == *"Wine packages"* ]]; then
    step "U-8" "Removing System Wine Packages"
    log info "Removing Wine packages from system"

    warn "Removing Wine will break ALL other Wine applications on this system."
    warn "Other Wine prefixes (e.g. ~/.wine) will remain but cannot run."

    local wine_pkgs=(
      "wine" "wine-core" "wine-common" "wine-filesystem" "wine-fonts"
      "wine-alsa" "wine-pulseaudio" "winetricks"
    )

    # แสดงรายการที่จะลบจริง (เฉพาะที่ติดตั้งอยู่)
    info "Packages that will be removed:"
    for pkg in "${wine_pkgs[@]}"; do
      rpm -q "$pkg" >/dev/null 2>&1 && kv "  remove" "$pkg"
    done
    echo ""

    if gum confirm "Confirm removal of Wine packages?"; then
      run_step monkey "Removing Wine packages" \
        bash -c "sudo $PKG_MGR remove -y ${wine_pkgs[*]} 2>/dev/null; true"

      run_step_optional dot "DNF autoremove orphans" \
        bash -c "sudo $PKG_MGR autoremove -y 2>/dev/null; true"

      log info "Wine packages removed from system"
    else
      warn "Wine package removal skipped."
      log info "Wine package removal skipped by user"
    fi
  else
    log info "Wine packages kept (LINE-only removal)"
    command -v wine >/dev/null 2>&1 && info "Wine $(wine --version) still installed."
  fi

  # ── U-9: Reload desktop environment ──────────────────────────────────────
  step "U-9" "Reloading Desktop"
  log info "Refreshing desktop environment"

  run_step_optional dot "Updating application database" \
    bash -c '
      update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
      # KDE: rebuild service cache
      command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 2>/dev/null || true
      # GNOME: refresh shell (ถ้าเป็น X11)
      if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
        command -v gnome-shell >/dev/null 2>&1 && \
          pkill -HUP gnome-shell 2>/dev/null || true
      fi
      true
    '

  log info "Desktop refreshed"

  # ── Summary ───────────────────────────────────────────────────────────────
  _show_uninstall_summary "$REMOVE_LEVEL"

  # ลบ log dir สุดท้าย (ถ้าเลือกไว้)
  if [ "${REMOVE_LOGS_AFTER:-false}" = true ]; then
    rm -rf "$LOG_DIR" 2>/dev/null || true
  fi
}

_show_uninstall_summary() {
  local level="${1:-unknown}"
  log info "Uninstallation complete"

  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold \
    "✔  LINE DEEP UNINSTALL COMPLETE")

  local checks=(
    "Wine Prefix:      $([ -d "$WINE_PREFIX" ] && echo '✗ Still exists' || echo '✔ Removed')"
    "Shortcuts:        $([ -f "$HOME/.local/share/applications/line.desktop" ] && echo '✗ Still exists' || echo '✔ Removed')"
    "Icons:            ✔ hicolor + pixmaps + ~/.icons cleaned"
    "Temp files:       ✔ /tmp cleaned"
    "Winetricks cache: $([ -d "$HOME/.cache/winetricks" ] && echo 'Kept' || echo '✔ Removed')"
    "Install logs:     $([ "${REMOVE_LOGS_AFTER:-false}" = true ] && echo '✔ Removed' || echo "Kept at $LOG_DIR")"
    "Wine packages:    $(command -v wine >/dev/null 2>&1 && echo "Kept ($(wine --version 2>/dev/null))" || echo '✔ Removed')"
    "App menu DB:      ✔ Rebuilt"
    "Removal level:    $level"
  )

  local rows=""
  for c in "${checks[@]}"; do
    rows+="  $c\n"
  done

  local hint
  hint=$(gum style --foreground "$C_WARNING" \
    " ℹ  If LINE icon still appears in app menu — log out and back in to force desktop refresh.")

  gum style \
    --border rounded --border-foreground "$C_SUCCESS" \
    --padding "1 3" \
    "$title" "" "$(printf '%b' "$rows")" "" "$hint"
}

repair_line() {
  banner "REPAIRING LINE DESKTOP"
  log info "Starting repair"

  if [ "$AUTO_MODE" = false ]; then
    if ! gum confirm "Repair LINE installation without removing your data?"; then
      log info "Repair cancelled by user"
      return 0
    fi
  fi

  local line_root="$WINE_PREFIX/drive_c/users/$USER/AppData/Local/LINE"
  local bin_dir="$line_root/bin"

  run_step monkey "Removing LINE binaries" rm -rf "$bin_dir"
  run_step dot "Cleaning installer cache" rm -f "$INSTALLER_PATH"

  install_line
  create_shortcut

  log info "Repair complete"
  ok "LINE repaired without deleting data"
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────

main() {
  # Parse Arguments
  for arg in "$@"; do
    case $arg in
      --auto|-y) AUTO_MODE=true ;;
      --verbose|-v) VERBOSE_MODE=true ;;
    esac
  done

  trap 'TRAP_EXIT=$?; TRAP_LINE=$LINENO; TRAP_CMD=$BASH_COMMAND; log error "Unexpected failure" \
    line="$TRAP_LINE" \
    exit="$TRAP_EXIT" \
    command="$TRAP_CMD"; gum style --foreground "$C_DANGER" \
    "Last command: $TRAP_CMD" \
    "At line: $TRAP_LINE" \
    "Exit code: $TRAP_EXIT" \
    "Full log: $LOG_FILE"' ERR
  
  banner "LINE DESKTOP INSTALLER (WINE 64-BIT)"
  
  local ACTION
  if [ "$AUTO_MODE" = true ]; then
    ACTION="🟢  Install LINE"
    log info "Auto-mode enabled: Defaulting to Install"
  else
    ACTION=$(gum choose \
      --header "Select action:" \
      --cursor "▶ " \
      --cursor.foreground "$C_PRIMARY" \
      --selected.foreground "$C_SUCCESS" \
      "🟢  Install LINE" \
      "🔴  Uninstall LINE" \
      "🛠️  Repair LINE" \
      "❌  Exit")
  fi

  case "$ACTION" in
    *Install*)
      log info "User selected: Install"
      detect_os
      check_dependencies
      detect_session
      
      local PIPELINE=(
        "install_wine"
        "setup_prefix"
        "install_dependencies"
        "apply_fixes"
        "install_line"
        "create_shortcut"
      )

      local step_num=1
      for task in "${PIPELINE[@]}"; do
        if ! "$task"; then
          log error "Task failed" task="$task"
          warn "Task '${task}' failed — check logs"
        fi
        (( step_num++ ))
      done
      show_summary
      ;;
    *Repair*)
      log info "User selected: Repair"
      detect_os
      check_dependencies
      detect_session
      repair_line
      ;;
    *Uninstall*)
      log info "User selected: Uninstall"
      detect_os
      uninstall_line
      ;;
    *)
      log info "User exited"
      exit 0
      ;;
  esac
}

main "$@"
