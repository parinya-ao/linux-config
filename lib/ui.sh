[[ -n "${_LIB_UI_LOADED:-}" ]] && return 0

_HAS_GUM=false
command -v gum &>/dev/null && _HAS_GUM=true

step() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 39 --bold "[STEP] $*"
  else
    printf "\e[34;1m[STEP] %s\e[0m\n" "$*"
  fi
}

ok() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 82 "[OK] $*"
  else
    printf "\e[32m[OK] %s\e[0m\n" "$*"
  fi
}

warn() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 227 "[WARN] $*" >&2
  else
    printf "\e[33m[WARN] %s\e[0m\n" "$*" >&2
  fi
}

fail() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 196 --bold "[FAIL] $*" >&2
  else
    printf "\e[31;1m[FAIL] %s\e[0m\n" "$*" >&2
  fi
  exit 1
}

info() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 51 "[INFO] $*"
  else
    printf "\e[36m[INFO] %s\e[0m\n" "$*"
  fi
}

skip() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style --foreground 244 "[SKIP] $*"
  else
    printf "\e[90m[SKIP] %s\e[0m\n" "$*"
  fi
}

status_line() {
  if [[ "$_HAS_GUM" == "true" ]]; then
    gum style "$*"
  else
    printf "%s\n" "$*"
  fi
}

export _LIB_UI_LOADED=1
