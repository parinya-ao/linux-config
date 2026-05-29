#!/usr/bin/env bash
# ==============================================================================
# Script: install-fvm.sh
# Description: Production-grade, modular FVM (Flutter Version Management) installer.
# Architecture: KISS, state-validated, cross-platform (Linux/macOS).
# Dependencies: curl, tar
# Supports: bash, zsh, fish, dash, sh — Nix-managed configs handled gracefully.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Global State & Configuration
# ------------------------------------------------------------------------------
readonly LOG_FILE="/tmp/fvm_install_$(date +%s).log"
readonly FVM_OFFICIAL_URL="https://fvm.app/install.sh"
readonly DEFAULT_INSTALL_DIR="$HOME/fvm"
readonly FVM_CONFIG_DIR="$HOME/.config/fvm"
readonly FVM_FISH_CONFD="$HOME/.config/fish/conf.d"

CURRENT_STATE="INIT"
FVM_VERSION=""
FVM_INSTALL_DIR="${FVM_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
UNINSTALL_MODE=0
CHECK_ONLY=0
DEBUG_MODE=0
PATH_ONLY=0

# ------------------------------------------------------------------------------
# 2. UI Palette
# ------------------------------------------------------------------------------
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAGENTA='\033[0;35m'
C_BOLD='\033[1m'
C_NC='\033[0m'

# ------------------------------------------------------------------------------
# 3. Logging Subsystem (Dual-output: File + Console)
# ------------------------------------------------------------------------------
log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        "INFO")   echo -e "${C_BLUE}[*]${C_NC} [${C_CYAN}INFO${C_NC}] $msg" >&2 ;;
        "OK")     echo -e "${C_GREEN}[+]${C_NC} [${C_GREEN}OK${C_NC}] $msg" >&2 ;;
        "WARN")   echo -e "${C_YELLOW}[!]${C_NC} [${C_YELLOW}WARN${C_NC}] $msg" >&2 ;;
        "ERR")    echo -e "${C_RED}[X]${C_NC} [${C_RED}ERROR${C_NC}] $msg" >&2 ;;
        "DEBUG")  echo -e "${C_MAGENTA}[~]${C_NC} [${C_MAGENTA}DEBUG${C_NC}] [STATE: ${C_CYAN}${CURRENT_STATE}${C_NC}] $msg" >&2 ;;
    esac
}

fail_exit() {
    log "ERR" "$1"
    log "INFO" "Execution halted. Diagnostics logged to: $LOG_FILE"
    exit 1
}

# ------------------------------------------------------------------------------
# 4. Trap & Error Handler
# ------------------------------------------------------------------------------
error_handler() {
    local exit_code=$?
    trap - ERR INT TERM
    log "ERR" "Script failed at state [${CURRENT_STATE}] with exit code ${exit_code}."
    log "INFO" "Review log for root cause: $LOG_FILE"
    exit "$exit_code"
}
trap 'error_handler' ERR INT TERM

# ------------------------------------------------------------------------------
# 5. Argument Parsing
# ------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                shift
                FVM_VERSION="$1"
                ;;
            --install-dir)
                shift
                FVM_INSTALL_DIR="$1"
                ;;
            --uninstall)
                UNINSTALL_MODE=1
                ;;
            --check)
                CHECK_ONLY=1
                ;;
            --path-only)
                PATH_ONLY=1
                ;;
            --debug)
                DEBUG_MODE=1
                ;;
            -h|--help)
                cat <<'HELP_EOF'
Usage: bash install-fvm.sh [OPTIONS]

Install FVM (Flutter Version Management) on your system.

OPTIONS:
  --version <ver>     Install specific FVM version (e.g., 3.2.1)
  --install-dir <dir> Custom install directory (default: $HOME/fvm)
  --uninstall         Remove FVM installation
  --check             Check environment and current state (no install)
  --path-only         Only configure PATH (skip install/uninstall)
  --debug             Enable verbose debug logging
  -h, --help          Show this help message

ENVIRONMENT VARIABLES:
  FVM_INSTALL_DIR     Override default install directory
  FVM_VERSION         Override default FVM version

EXAMPLES:
  bash install-fvm.sh                              # Latest + PATH all shells
  bash install-fvm.sh --version 3.2.1              # Specific version
  bash install-fvm.sh --install-dir /opt/fvm       # Custom path
  bash install-fvm.sh --check                      # Dry run
  bash install-fvm.sh --path-only                  # Configure PATH only
  bash install-fvm.sh --uninstall                  # Remove FVM
  FVM_INSTALL_DIR=/opt/fvm bash install-fvm.sh     # Via env var
HELP_EOF
                exit 0
                ;;
            *)
                fail_exit "Unknown argument: $1. Use --help for usage."
                ;;
        esac
        shift
    done
}

# ------------------------------------------------------------------------------
# 6. Environment Validation
# ------------------------------------------------------------------------------
check_environment() {
    CURRENT_STATE="CHECK_ENV"

    # OS detection
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        log "INFO" "OS: ${PRETTY_NAME:-$ID} ($(uname -m))"
    elif [[ "$(uname)" == "Darwin" ]]; then
        log "INFO" "OS: macOS ($(uname -m))"
    else
        log "INFO" "OS: $(uname) ($(uname -m))"
    fi

    # Required commands
    if ! command -v curl >/dev/null 2>&1; then
        fail_exit "curl is required. Install it first (e.g., sudo apt install curl / sudo dnf install curl)."
    fi
    if ! command -v tar >/dev/null 2>&1; then
        fail_exit "tar is required. Install it first."
    fi

    log "DEBUG" "curl: $(command -v curl)"
    log "DEBUG" "tar: $(command -v tar)"
    log "DEBUG" "Install target dir: $FVM_INSTALL_DIR"

    log "OK" "Environment validation passed."
}

# ------------------------------------------------------------------------------
# 7. Existing Installation Check
# ------------------------------------------------------------------------------
check_existing() {
    CURRENT_STATE="CHECK_EXISTING"

    local fvm_bin="$FVM_INSTALL_DIR/bin/fvm"

    if [[ -x "$fvm_bin" ]]; then
        local current_version
        current_version=$("$fvm_bin" --version 2>/dev/null || echo "unknown")
        log "INFO" "FVM already installed at: $fvm_bin"
        log "INFO" "Current version: $current_version"
        log "INFO" "Install dir: $FVM_INSTALL_DIR"
        return 0
    fi

    if [[ -d "$FVM_INSTALL_DIR" ]]; then
        log "WARN" "Directory $FVM_INSTALL_DIR exists but no fvm binary found."
        log "WARN" "This may be a partial/leftover installation."
    fi

    return 1
}

# ------------------------------------------------------------------------------
# 8. Shell Configuration Detection
# ------------------------------------------------------------------------------
detect_shell_configs() {
    CURRENT_STATE="DETECT_SHELL"

    local path_line="export PATH=\"$FVM_INSTALL_DIR/bin:\$PATH\""
    local configs=()

    # Bash
    if [[ -f "$HOME/.bashrc" ]]; then
        configs+=("$HOME/.bashrc")
    fi
    if [[ -f "$HOME/.bash_profile" ]]; then
        configs+=("$HOME/.bash_profile")
    fi
    # Zsh
    if [[ -f "$HOME/.zshrc" ]]; then
        configs+=("$HOME/.zshrc")
    fi
    # Profile
    if [[ -f "$HOME/.profile" ]]; then
        configs+=("$HOME/.profile")
    fi

    log "DEBUG" "Shell configs found: ${configs[*]:-(none)}"

    echo "$path_line"
    [[ ${#configs[@]} -gt 0 ]] && printf '%s\n' "${configs[@]}"
}

# ------------------------------------------------------------------------------
# 9. Core: Install FVM
# ------------------------------------------------------------------------------
install_fvm() {
    CURRENT_STATE="INSTALL_FVM"

    local install_url="$FVM_OFFICIAL_URL"
    local version_flag=""
    local version_label="latest"

    if [[ -n "$FVM_VERSION" ]]; then
        version_flag="-s -- $FVM_VERSION"
        version_label="$FVM_VERSION"
    fi

    log "INFO" "Downloading FVM ($version_label) from $install_url"
    log "INFO" "Install target: $FVM_INSTALL_DIR"
    log "DEBUG" "Executing: curl -fsSL $install_url | bash $version_flag (with FVM_INSTALL_DIR=$FVM_INSTALL_DIR)"

    mkdir -p "$(dirname "$FVM_INSTALL_DIR")"

    if [[ -n "$FVM_VERSION" ]]; then
        FVM_INSTALL_DIR="$FVM_INSTALL_DIR" \
            curl -fsSL "$install_url" | bash -s -- "$FVM_VERSION" 2>>"$LOG_FILE"
    else
        FVM_INSTALL_DIR="$FVM_INSTALL_DIR" \
            curl -fsSL "$install_url" | bash 2>>"$LOG_FILE"
    fi

    local exit_code=${PIPESTATUS[1]:-${PIPESTATUS[0]:-1}}

    if [[ $exit_code -ne 0 ]]; then
        fail_exit "FVM install script failed with exit code $exit_code."
    fi

    log "OK" "FVM install script completed successfully."
}

# ------------------------------------------------------------------------------
# 10. Core: Verify FVM
# ------------------------------------------------------------------------------
verify_installation() {
    CURRENT_STATE="VERIFY_INSTALL"

    local fvm_bin="$FVM_INSTALL_DIR/bin/fvm"

    if [[ ! -x "$fvm_bin" ]]; then
        fail_exit "FVM binary not found at $fvm_bin after installation."
    fi

    local version_output
    version_output=$("$fvm_bin" --version 2>&1 || true)
    log "OK" "FVM binary verified: $fvm_bin"
    log "INFO" "FVM version: $version_output"

    if [[ "$DEBUG_MODE" -eq 1 ]]; then
        log "DEBUG" "Running: fvm --help (first 5 lines)"
        "$fvm_bin" --help 2>&1 | head -5 | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        log "DEBUG" "Listing cached Flutter SDKs..."
        "$fvm_bin" list 2>&1 | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done || log "DEBUG" "No cached SDKs (fresh install)."
    fi
}

# ------------------------------------------------------------------------------
# 11. Universal PATH Loader (POSIX sh — sourced by bash/zsh/sh/dash/ksh)
# ------------------------------------------------------------------------------
write_universal_loader() {
    CURRENT_STATE="WRITE_LOADER"

    mkdir -p "$FVM_CONFIG_DIR"

    local loader="$FVM_CONFIG_DIR/path.sh"
    local fvm_bin_dir="$FVM_INSTALL_DIR/bin"

    cat > "$loader" <<-LOADER_EOF
# FVM PATH loader — auto-generated by install-fvm.sh
# Source this file from any POSIX shell:  . "${loader}"
case ":${PATH}:" in
  *:"${fvm_bin_dir}":*) ;;
  *) export PATH="${fvm_bin_dir}:${PATH}" ;;
esac
LOADER_EOF

    log "OK" "Universal PATH loader: $loader"
    log "DEBUG" "Loader contents: $(tr '\n' ' ' < "$loader")"

    echo "$loader"
}

# ------------------------------------------------------------------------------
# 12. PATH Configuration — Every Shell on the System
# ------------------------------------------------------------------------------
configure_all_shells_path() {
    CURRENT_STATE="CONFIGURE_SHELL_PATH"

    local fvm_bin_dir="$FVM_INSTALL_DIR/bin"
    local loader
    loader=$(write_universal_loader)

    local nix_store_symlink=""
    if [[ "$(uname)" == "Linux" ]]; then
        nix_store_symlink="/nix/store"
    fi

    # Update current session
    export PATH="$fvm_bin_dir:$PATH"
    log "INFO" "Current session PATH updated."

    # --- fish: conf.d/ auto-loading + universal var for current session ---
    if command -v fish >/dev/null 2>&1; then
        CURRENT_STATE="CONFIGURE_FISH"
        mkdir -p "$FVM_FISH_CONFD"
        local fish_loader="$FVM_FISH_CONFD/fvm.fish"
        cat > "$fish_loader" <<-FISH_EOF
# FVM PATH — auto-generated by install-fvm.sh
if not contains "$fvm_bin_dir" \$fish_user_paths
    fish_add_path "$fvm_bin_dir"
end
FISH_EOF
        log "OK" "Fish PATH configured: $fish_loader"

        # Apply to current fish session immediately via universal variable
        if fish -c "fish_add_path $fvm_bin_dir" >/dev/null 2>&1; then
            log "OK" "Fish: PATH updated for current session (universal var)."
        else
            fish -c "set -U fish_user_paths $fvm_bin_dir \$fish_user_paths" >/dev/null 2>&1 && \
                log "OK" "Fish: PATH updated via fish_user_paths." || \
                log "WARN" "Fish: could not update PATH for current session."
        fi
    else
        log "DEBUG" "Fish not installed; skipping."
    fi

    # --- bash: .bashrc ---
    if command -v bash >/dev/null 2>&1; then
        CURRENT_STATE="CONFIGURE_BASH"
        local bash_source_line=". \"$loader\""
        local bash_rc="$HOME/.bashrc"
        local bash_rc_d_fvm="$HOME/.bashrc.d/fvm.sh"

        if [[ -f "$bash_rc_d_fvm" ]]; then
            log "DEBUG" "bash: FVM already configured via .bashrc.d/fvm.sh; skipping."
        elif [[ -f "$bash_rc" ]]; then
            if grep -Fq "$fvm_bin_dir" "$bash_rc" 2>/dev/null; then
                log "DEBUG" "bash: PATH already in $bash_rc"
            elif is_nix_managed "$bash_rc"; then
                log "DEBUG" "bash: $bash_rc is Nix-managed — wrapping with rc.d auto-source."
                bashrc_d_fallback "$bash_source_line" bash "$loader"
            elif [[ -w "$bash_rc" ]]; then
                printf '\n%s\n' "$bash_source_line" >> "$bash_rc"
                log "OK" "bash: added FVM PATH to $bash_rc"
            fi
        else
            log "DEBUG" "bash: no .bashrc found — creating one with rc.d auto-source."
            bashrc_d_fallback "$bash_source_line" bash "$loader"
        fi
    else
        log "DEBUG" "bash not installed; skipping."
    fi

    # --- zsh: .zshrc ---
    if command -v zsh >/dev/null 2>&1; then
        CURRENT_STATE="CONFIGURE_ZSH"
        local zsh_source_line=". \"$loader\""
        local zsh_rc="$HOME/.zshrc"
        local zsh_rc_d_fvm="$HOME/.zshrc.d/fvm.sh"

        if [[ -f "$zsh_rc_d_fvm" ]]; then
            log "DEBUG" "zsh: FVM already configured via .zshrc.d/fvm.sh; skipping."
        elif [[ -f "$zsh_rc" ]]; then
            if grep -Fq "$fvm_bin_dir" "$zsh_rc" 2>/dev/null; then
                log "DEBUG" "zsh: PATH already in $zsh_rc"
            elif is_nix_managed "$zsh_rc"; then
                log "WARN" "zsh: $zsh_rc is Nix-managed — wrapping with rc.d auto-source."
                bashrc_d_fallback "$zsh_source_line" zsh "$loader"
            elif [[ -w "$zsh_rc" ]]; then
                printf '\n%s\n' "$zsh_source_line" >> "$zsh_rc"
                log "OK" "zsh: added FVM PATH to $zsh_rc"
            fi
        else
            log "DEBUG" "zsh: no .zshrc found — creating one with rc.d auto-source."
            bashrc_d_fallback "$zsh_source_line" zsh "$loader"
        fi
    else
        log "DEBUG" "zsh not installed; skipping."
    fi

    # --- dash / sh (POSIX) ---
    for shell_cmd in dash ksh sh; do
        if command -v "$shell_cmd" >/dev/null 2>&1 && [[ "$shell_cmd" != "$(readlink -f /proc/$$/exe 2>/dev/null || true)" ]]; then
            CURRENT_STATE="CONFIGURE_${shell_cmd^^}"
            local rcfile="$HOME/.${shell_cmd}rc"
            local source_line=". \"$loader\""

            if [[ -f "$rcfile" ]]; then
                if grep -Fq "$fvm_bin_dir" "$rcfile" 2>/dev/null; then
                    log "DEBUG" "${shell_cmd}: PATH already in $rcfile"
                elif is_nix_managed "$rcfile"; then
                    log "WARN" "${shell_cmd}: $rcfile is Nix-managed (read-only)."
                    log "INFO" "  → Source '$loader' in your ${shell_cmd} config."
                elif [[ -w "$rcfile" ]]; then
                    printf '\n%s\n' "$source_line" >> "$rcfile"
                    log "OK" "${shell_cmd}: added FVM PATH to $rcfile"
                fi
            else
                log "DEBUG" "${shell_cmd}: no rc file found at $rcfile; skipping."
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# Helper: detect Nix-managed files (symlinks into /nix/store)
# ------------------------------------------------------------------------------
is_nix_managed() {
    local path="$1"
    if [[ -L "$path" ]]; then
        local target
        target=$(readlink -f "$path" 2>/dev/null || true)
        if [[ "$target" == /nix/store/* ]]; then
            return 0
        fi
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Helper: fallback when shell config is Nix-managed
# ------------------------------------------------------------------------------
bashrc_d_fallback() {
    local source_line="$1"
    local shell_name="$2"
    local loader="$3"

    local rc_file="$HOME/.${shell_name}rc"
    local rc_d_dir="$HOME/.${shell_name}rc.d"

    mkdir -p "$rc_d_dir"

    # Write FVM PATH loader into rc.d/fvm.sh
    local fvm_rc_d="$rc_d_dir/fvm.sh"
    if ! grep -Fq "$loader" "$fvm_rc_d" 2>/dev/null; then
        printf '%s\n' "$source_line" > "$fvm_rc_d"
        log "OK" "${shell_name}: created $fvm_rc_d"
    else
        log "DEBUG" "${shell_name}: $fvm_rc_d already configured; skipping."
    fi

    # If rc file is Nix-managed → wrap it with a local file that sources original + rc.d/
    if is_nix_managed "$rc_file"; then
        local nix_target
        nix_target=$(readlink -f "$rc_file")

        rm -f "$rc_file"
        cat > "$rc_file" <<-WRAPPER_EOF
# Wrapper — auto-generated by install-fvm.sh
# Original Nix-managed config: ${nix_target}
. "${nix_target}"

# Auto-source local overrides from ${rc_d_dir}/
for f in "${rc_d_dir}/"*.sh; do
    [ -r "\$f" ] && . "\$f"
done
WRAPPER_EOF
        log "OK" "${shell_name}: wrapped Nix symlink → ${rc_file}"
        log "OK" "${shell_name}: now auto-sources ${rc_d_dir}/"

    # No rc file exists at all → create one with rc.d/ sourcing
    elif [[ ! -f "$rc_file" ]]; then
        cat > "$rc_file" <<-RC_EOF
# Created by install-fvm.sh — auto-sources ${rc_d_dir}/
for f in "${rc_d_dir}/"*.sh; do
    [ -r "\$f" ] && . "\$f"
done
RC_EOF
        log "OK" "${shell_name}: created ${rc_file} with rc.d auto-source"
    fi
}

# ------------------------------------------------------------------------------
# 13. Uninstall
# ------------------------------------------------------------------------------
uninstall_fvm() {
    CURRENT_STATE="UNINSTALL"

    local fvm_bin="$FVM_INSTALL_DIR/bin/fvm"

    if [[ ! -d "$FVM_INSTALL_DIR" ]]; then
        log "WARN" "FVM installation directory not found at $FVM_INSTALL_DIR."
    else
        log "INFO" "Uninstalling FVM from $FVM_INSTALL_DIR..."

        if [[ -x "$fvm_bin" ]]; then
            log "DEBUG" "Removing cached Flutter SDKs (fvm destroy)..."
            "$fvm_bin" destroy 2>>"$LOG_FILE" || log "WARN" "fvm destroy failed or not supported."
        fi

        if rm -rf "$FVM_INSTALL_DIR" 2>>"$LOG_FILE"; then
            log "OK" "Removed FVM directory: $FVM_INSTALL_DIR"
        fi
    fi

    # Remove generated config files
    if [[ -d "$FVM_CONFIG_DIR" ]]; then
        rm -rf "$FVM_CONFIG_DIR"
        log "OK" "Removed config dir: $FVM_CONFIG_DIR"
    fi

    local fish_loader="$FVM_FISH_CONFD/fvm.fish"
    if [[ -f "$fish_loader" ]]; then
        rm -f "$fish_loader"
        log "OK" "Removed: $fish_loader"
    fi

    # Clean up bash/zsh: remove rc.d files, restore Nix symlinks
    for shell_name in bash zsh; do
        local rc_file="$HOME/.${shell_name}rc"
        local rc_d_dir="$HOME/.${shell_name}rc.d"
        local fvm_rc_d="$rc_d_dir/fvm.sh"

        # Remove FVM loader from rc.d
        [[ -f "$fvm_rc_d" ]] && rm -f "$fvm_rc_d" && log "OK" "Removed: $fvm_rc_d"

        # If .bashrc / .zshrc is our wrapper (contains "auto-generated by install-fvm.sh"), restore Nix symlink
        if [[ -f "$rc_file" ]] && grep -q "auto-generated by install-fvm.sh" "$rc_file" 2>/dev/null; then
            local nix_target
            nix_target=$(grep "^# Original Nix-managed config:" "$rc_file" 2>/dev/null | sed 's/^# Original Nix-managed config: //')
            if [[ -n "$nix_target" ]] && [[ -f "$nix_target" ]]; then
                rm -f "$rc_file"
                ln -s "$nix_target" "$rc_file"
                log "OK" "${shell_name}: restored Nix symlink → $rc_file"
            fi
        fi
    done

    # Remove PATH entries from shell configs (legacy direct writes)
    local path_line="export PATH=\"$FVM_INSTALL_DIR/bin:\$PATH\""
    for config in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$config" ]] && [[ -w "$config" ]] && ! is_nix_managed "$config"; then
            if grep -Fqx "$path_line" "$config" 2>/dev/null; then
                grep -Fxv "$path_line" "$config" > "${config}.tmp" && mv "${config}.tmp" "$config"
                log "OK" "Removed FVM PATH from $config"
            fi
        fi
    done

    # Remove fish PATH
    if command -v fish >/dev/null 2>&1; then
        fish -c "set -U fish_user_paths (string match -v '$FVM_INSTALL_DIR/bin' \$fish_user_paths)" >/dev/null 2>&1 || true
        log "DEBUG" "Cleaned FVM from Fish PATH."
    fi

    log "OK" "FVM uninstalled successfully."
}

# ------------------------------------------------------------------------------
# 14. Summary & Next Steps
# ------------------------------------------------------------------------------
show_summary() {
    CURRENT_STATE="SUMMARY"

    local fvm_bin="$FVM_INSTALL_DIR/bin/fvm"
    local version_output="not installed"
    [[ -x "$fvm_bin" ]] && version_output=$("$fvm_bin" --version 2>/dev/null || echo "unknown")

    local sep
    sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '=')

    echo ""
    echo -e "${C_BOLD}${sep}${C_NC}"
    echo -e "  ${C_BOLD}FVM Installation Complete${C_NC}"
    echo -e "${C_BOLD}${sep}${C_NC}"
    echo ""
    echo -e "  ${C_CYAN}Install Dir:${C_NC}  $FVM_INSTALL_DIR"
    echo -e "  ${C_CYAN}Binary:${C_NC}      $fvm_bin"
    echo -e "  ${C_CYAN}Version:${C_NC}     $version_output"
    echo -e "  ${C_CYAN}Log File:${C_NC}    $LOG_FILE"
    echo ""
    echo -e "  ${C_BOLD}Next Steps:${C_NC}"
    echo ""
    echo "  1. Restart your shell or run:"
    echo "       source ~/.bashrc   # or ~/.zshrc"
    echo ""
    echo "  2. Pin Flutter SDK to a project:"
    echo "       cd /path/to/project"
    echo "       fvm install <version>"
    echo "       fvm use <version>"
    echo ""
    echo "  3. List installed versions:"
    echo "       fvm list"
    echo ""
    echo "  4. Set global default (optional):"
    echo "       fvm global <version>"
    echo ""
    echo -e "  ${C_BOLD}Documentation:${C_NC} https://fvm.app"
    echo ""
}

# ------------------------------------------------------------------------------
# 15. Check-Only Mode
# ------------------------------------------------------------------------------
run_check() {
    CURRENT_STATE="CHECK_MODE"

    local fvm_bin="$FVM_INSTALL_DIR/bin/fvm"
    local status="NOT INSTALLED"
    local version_info=""

    if [[ -x "$fvm_bin" ]]; then
        status="INSTALLED"
        version_info=$("$fvm_bin" --version 2>/dev/null || true)
    fi

    local sep
    sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '=')

    echo -e "${C_BOLD}${sep}${C_NC}"
    echo -e "  ${C_BOLD}FVM Environment Check${C_NC}"
    echo -e "${C_BOLD}${sep}${C_NC}"
    echo ""
    echo -e "  ${C_CYAN}FVM Status:${C_NC}      $status"
    echo -e "  ${C_CYAN}Install Dir:${C_NC}   $FVM_INSTALL_DIR"
    echo -e "  ${C_CYAN}Binary:${C_NC}        $fvm_bin"
    echo -e "  ${C_CYAN}Version:${C_NC}       ${version_info:--}"
    echo -e "  ${C_CYAN}Platform:${C_NC}      $(uname -om)"
    echo -e "  ${C_CYAN}curl:${C_NC}          $(command -v curl || echo "MISSING")"
    echo -e "  ${C_CYAN}tar:${C_NC}           $(command -v tar || echo "MISSING")"
    echo ""

    # PATH loader status
    local loader="$FVM_CONFIG_DIR/path.sh"
    if [[ -f "$loader" ]]; then
        echo -e "  ${C_CYAN}PATH Loader:${C_NC}     $loader ${C_GREEN}(exists)${C_NC}"
    else
        echo -e "  ${C_CYAN}PATH Loader:${C_NC}     $loader ${C_YELLOW}(not created)${C_NC}"
    fi

    local fish_loader="$FVM_FISH_CONFD/fvm.fish"
    if [[ -f "$fish_loader" ]]; then
        echo -e "  ${C_CYAN}Fish conf.d:${C_NC}     $fish_loader ${C_GREEN}(exists)${C_NC}"
    fi

    echo ""
    echo -e "  ${C_BOLD}Shell PATH Status:${C_NC}"
    for shell_cmd in bash zsh fish dash sh ksh; do
        if command -v "$shell_cmd" >/dev/null 2>&1; then
            local in_path="no"
            if "$shell_cmd" -c "echo \"\$PATH\"" 2>/dev/null | grep -q "$FVM_INSTALL_DIR/bin"; then
                in_path="${C_GREEN}yes${C_NC}"
            else
                in_path="${C_YELLOW}no${C_NC}"
            fi
            echo -e "  ${C_CYAN}${shell_cmd}:${C_NC}          PATH includes FVM? $in_path"
        fi
    done
    echo ""
}

# ------------------------------------------------------------------------------
# 16. Main Orchestrator
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"

    log "INFO" "FVM Installation Manager"
    log "INFO" "Log file: $LOG_FILE"
    echo -e "${C_BOLD}${C_CYAN}=== FVM (Flutter Version Management) Installer ===${C_NC}"

    # Check mode: validate environment and report
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        check_environment
        check_existing || true
        run_check
        exit 0
    fi

    # PATH-only mode: skip install, just configure PATH for all shells
    if [[ "$PATH_ONLY" -eq 1 ]]; then
        log "INFO" "PATH-only mode: configuring FVM PATH for all shells..."
        configure_all_shells_path
        run_check
        exit 0
    fi

    # Uninstall mode
    if [[ "$UNINSTALL_MODE" -eq 1 ]]; then
        uninstall_fvm
        exit 0
    fi

    # Full install workflow
    check_environment

    if check_existing; then
        log "INFO" "FVM is already installed."
        echo -e "  ${C_YELLOW}Use --path-only to configure PATH, or --uninstall to remove.${C_NC}"
        exit 0
    fi

    install_fvm
    verify_installation
    configure_all_shells_path
    show_summary

    # Confirm fvm is reachable from parent shell
    if command -v fish >/dev/null 2>&1 && [[ "$(ps -o comm= -p "$PPID" 2>/dev/null || true)" == "fish" ]]; then
        if fish -c "command -v fvm" >/dev/null 2>&1; then
            log "OK" "fvm confirmed accessible in this fish session."
        else
            log "WARN" "fvm installed but not yet active in current fish session."
            log "INFO" "Run: exec fish   (or open a new terminal)"
        fi
    fi

    log "OK" "FVM installation completed successfully."
}

# Execute only when invoked directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
