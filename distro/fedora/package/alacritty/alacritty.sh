#!/usr/bin/env bash
set -Eeuo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"    # Deep Sky Blue
readonly C_SUCCESS="#04B575"    # Mint Green
readonly C_WARNING="#FFA500"    # Amber
readonly C_DANGER="#FF4500"     # Red-Orange
readonly C_MUTED="#666666"      # Dim Gray
readonly C_ACCENT="#C678DD"     # Soft Purple

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"

TARGET_USER="${SUDO_USER:-$USER}"
LOG_FILE="/tmp/alacritty_install_${TARGET_USER}.log"
BUILD_DIR="/tmp/alacritty_build_${TARGET_USER}"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────
banner() {
  gum style --border double --border-foreground "$C_PRIMARY" --align center --padding "1 4" --bold "$*"
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
  if [[ -f "$LOG_FILE" ]]; then
    echo -e "\n--- LAST 20 LINES OF LOG ($LOG_FILE) ---"
    tail -n 20 "$LOG_FILE"
    echo -e "----------------------------------------\n"
  fi
  gum style --border thick --border-foreground "$C_DANGER" --foreground "$C_DANGER" --bold --padding "0 2" "✖  ERROR: $*"
  exit 1
}

info() {
  gum style --foreground "$C_MUTED" "  ℹ  $*"
}

kv() {
  local label value
  label=$(gum style --foreground "$C_MUTED" --width 18 "$1")
  value=$(gum style --foreground "$C_ACCENT" "$2")
  gum join --horizontal "$label" "$value"
}

# ── LAYER 2: RUNNER HELPER ──────────────────────────────────────────────────
run_step() {
  local spinner="$1" title="$2"
  shift 2
  
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: $title (would execute: $*)"
    return 0
  fi

  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    local code=$?
    fail "$title (failed with exit code $code)"
  fi
}

# ── LAYER 3: TASK FUNCTIONS ──────────────────────────────────────────────────

# Ensure the environment is ready for installation
check_environment() {
  if ! command -v dnf >/dev/null 2>&1; then
    fail "Package manager 'dnf' not found. This script is intended for Fedora."
  fi

  if ! sudo -v >/dev/null 2>&1; then
    fail "Sudo access is required for installation."
  fi
}

# Install native packages required for compilation
install_system_dependencies() {
  local deps=(cmake freetype-devel fontconfig-devel libxcb-devel libxkbcommon-devel g++ scdoc gzip git)
  info "Refreshing dnf metadata..."
  sudo dnf clean all && sudo dnf makecache --refresh
  run_step line "Installing build dependencies" sudo dnf install -y "${deps[@]}"
}

# Prepare the Rust toolchain for Alacritty
prepare_rust_toolchain() {
  if ! command -v rustup >/dev/null 2>&1; then
    info "Rust not found. Installing via rustup.rs..."
    run_step globe "Installing Rust" bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      info "DRY RUN: Would source $HOME/.cargo/env and continue."
    else
      # shellcheck disable=SC1091
      source "$HOME/.cargo/env"
    fi
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]] && ! command -v rustup >/dev/null 2>&1; then
    info "DRY RUN: Skipping rustup commands as rustup is not installed."
  else
    run_step points "Setting Rust toolchain to stable" rustup override set stable
    run_step points "Updating Rust stable" rustup update stable
  fi
}

# Clone Alacritty source code from GitHub
fetch_alacritty_source() {
  if [[ -d "$BUILD_DIR" ]]; then
    run_step trash "Cleaning existing build directory" rm -rf "$BUILD_DIR"
  fi
  run_step globe "Cloning Alacritty repository" git clone https://github.com/alacritty/alacritty.git "$BUILD_DIR"
  
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    mkdir -p "$BUILD_DIR"
    info "DRY RUN: Created dummy build directory for dry run safety."
  fi
}

# Compile the Alacritty binary in release mode
compile_alacritty_binary() {
  pushd "$BUILD_DIR" > /dev/null
  run_step line "Compiling Alacritty (Release)" cargo build --release
  
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    mkdir -p target/release
    touch target/release/alacritty
    info "DRY RUN: Created dummy binary for dry run safety."
  fi
  popd > /dev/null
}

# Install binary, desktop entry, and icon
install_application_files() {
  pushd "$BUILD_DIR" > /dev/null
  
  run_step dot "Installing binary to /usr/local/bin" sudo cp target/release/alacritty /usr/local/bin
  run_step dot "Installing application icon" sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
  run_step dot "Installing desktop entry" sudo desktop-file-install extra/linux/Alacritty.desktop
  run_step dot "Updating desktop database" sudo update-desktop-database
  
  popd > /dev/null
}

# Configure terminfo to ensure correct terminal behavior and colors
configure_terminfo() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    info "DRY RUN: Would check for and install terminfo."
    return 0
  fi

  if ! infocmp alacritty >/dev/null 2>&1; then
    pushd "$BUILD_DIR" > /dev/null
    run_step dot "Installing Alacritty terminfo" sudo tic -xe alacritty,alacritty-direct extra/alacritty.info
    popd > /dev/null
  else
    ok "Terminfo already installed"
  fi
}

# Set up Fish shell autocompletions
configure_fish_completions() {
  if command -v fish >/dev/null 2>&1; then
    local fish_comp_dir
    fish_comp_dir=$(fish -c 'echo $fish_complete_path[1]')
    
    run_step dot "Creating Fish completions directory" mkdir -p "$fish_comp_dir"
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      run_step dot "Installing Fish completions" echo "cp $BUILD_DIR/extra/completions/alacritty.fish $fish_comp_dir/alacritty.fish"
    else
      run_step dot "Installing Fish completions" cp "$BUILD_DIR/extra/completions/alacritty.fish" "$fish_comp_dir/alacritty.fish"
    fi
  else
    warn "Fish shell not found, skipping completions."
  fi
}

# Install manual pages using scdoc
install_manual_pages() {
  pushd "$BUILD_DIR" > /dev/null
  
  run_step dot "Creating manual page directories" sudo mkdir -p /usr/local/share/man/man1 /usr/local/share/man/man5 /usr/local/share/man/man7
  
  run_step dot "Generating man1 pages" bash -c "
    scdoc < extra/man/alacritty.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null
    scdoc < extra/man/alacritty-msg.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz > /dev/null
  "
  
  run_step dot "Generating man5 pages" bash -c "
    scdoc < extra/man/alacritty.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz > /dev/null
    scdoc < extra/man/alacritty-bindings.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz > /dev/null
  "
  
  run_step dot "Generating man7 pages" bash -c "
    scdoc < extra/man/alacritty-escapes.7.scd | gzip -c | sudo tee /usr/local/share/man/man7/alacritty-escapes.7.gz > /dev/null
  "
  
  popd > /dev/null
}

# ── LAYER 4: ORCHESTRATION ──────────────────────────────────────────────────
show_summary() {
  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  ALACRITTY INSTALLATION COMPLETE")
  
  local body
  body=$(gum join --vertical --align left "$title" "" \
    "$(kv "Application" "Alacritty")" \
    "$(kv "Binary" "/usr/local/bin/alacritty")" \
    "$(kv "Shell" "Fish (Completions Added)")" \
    "$(kv "Docs" "Man pages installed")")
    
  gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "$body"
}

main() {
  touch "$LOG_FILE"
  trap 'fail "Unexpected failure at line $LINENO. Check $LOG_FILE for details."' ERR

  banner "ALACRITTY INSTALLER"

  local PIPELINE=(
    "check_environment"
    "install_system_dependencies"
    "prepare_rust_toolchain"
    "fetch_alacritty_source"
    "compile_alacritty_binary"
    "install_application_files"
    "configure_terminfo"
    "configure_fish_completions"
    "install_manual_pages"
  )

  local step_num=1
  for task in "${PIPELINE[@]}"; do
    step "$step_num" "$task"
    "$task" >>"$LOG_FILE" 2>&1
    (( step_num++ ))
  done

  show_summary
}
main "$@"
