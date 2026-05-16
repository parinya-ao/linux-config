#!/usr/bin/env bash
set -euo pipefail

source "${BASH_SOURCE[0]%/*}/../../../lib/ui.sh"

BOOTSTRAP_USER="${SUDO_USER:-$(id -un)}"
BOOTSTRAP_HOME="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)"

as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

as_user() {
    if [[ $EUID -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$BOOTSTRAP_USER" env "HOME=$BOOTSTRAP_HOME" "$@"
    else
        "$@"
    fi
}

# ── Firefox Developer Edition ──────────────────────
step "Firefox Developer Edition"

REPO_NAME="home_ignis"
REPO_URL="https://download.opensuse.org/repositories/home:/ignis/openSUSE_Tumbleweed/"

if rpm -q firefox-dev &>/dev/null; then
    skip "Firefox Developer Edition already installed"
else
    if ! zypper lr 2>/dev/null | grep -q "$REPO_NAME"; then
        as_root zypper addrepo -f "$REPO_URL" "$REPO_NAME"
    fi
    as_root zypper --non-interactive --gpg-auto-import-keys refresh
    as_root zypper --non-interactive install firefox-dev
    ok "Firefox Developer Edition installed"
fi

# ── Brave Browser Beta ─────────────────────────────
step "Brave Browser Beta"

if rpm -q brave-browser-beta &>/dev/null; then
    skip "Brave Browser Beta already installed"
else
    as_root rpm --import https://brave-browser-rpm-beta.s3.brave.com/brave-core-beta.asc
    if ! zypper lr 2>/dev/null | grep -q "brave-browser-beta"; then
        as_root zypper addrepo \
            https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
    fi
    as_root zypper --non-interactive install brave-browser-beta
    ok "Brave Browser Beta installed"
fi

# ── Zed Editor (native) ───────────────────────────
step "Zed Editor"

ZED_BIN="${BOOTSTRAP_HOME}/.local/bin/zed"

if [[ -x "$ZED_BIN" ]]; then
    skip "Zed already installed at $ZED_BIN"
else
    as_user mkdir -p "${BOOTSTRAP_HOME}/.local/bin"
    as_user bash -c 'curl -fsSL https://zed.dev/install.sh | sh'

    if [[ -x "$ZED_BIN" ]]; then
        ok "Zed installed at $ZED_BIN"
    else
        warn "Zed install script ran but binary not found"
    fi
fi

ok "All additional packages configured"
