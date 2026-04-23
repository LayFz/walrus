#!/usr/bin/env bash
#
# walrus - utilities
# Interactive prompts, checks, and common helpers

# ─── Interactive Prompts ──────────────────────────────────

ask() {
  local prompt="$1" default="${2:-}"
  if [[ -n "$default" ]]; then
    printf "  ${C_CYAN}?${C_RESET} %s ${C_DIM}(%s)${C_RESET}: " "$prompt" "$default"
  else
    printf "  ${C_CYAN}?${C_RESET} %s: " "$prompt"
  fi
  read -r REPLY
  REPLY="${REPLY:-$default}"
}

ask_secret() {
  local prompt="$1"
  printf "  ${C_CYAN}?${C_RESET} %s: " "$prompt"
  read -rs REPLY
  echo ""
}

confirm() {
  local prompt="$1"
  printf "  ${C_CYAN}?${C_RESET} %s ${C_DIM}(Y/n)${C_RESET}: " "$prompt"
  local ans
  read -r ans
  [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]
}

# ─── Checks ───────────────────────────────────────────────

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "Please run as root: sudo walrus $*"
}

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is not installed"
}

# ─── Banner ───────────────────────────────────────────────

banner() {
  printf "%s" "${C_BOLD}"
  cat <<'BANNER'

  ██╗    ██╗ █████╗ ██╗     ██████╗ ██╗   ██╗███████╗
  ██║    ██║██╔══██╗██║     ██╔══██╗██║   ██║██╔════╝
  ██║ █╗ ██║███████║██║     ██████╔╝██║   ██║███████╗
  ██║███╗██║██╔══██║██║     ██╔══██╗██║   ██║╚════██║
  ╚███╔███╔╝██║  ██║███████╗██║  ██║╚██████╔╝███████║
   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
BANNER
  printf "%s\n" "${C_RESET}"
  printf "  ${C_DIM}PostgreSQL backup buddy for indie hackers  v%s${C_RESET}\n\n" "${WALRUS_VERSION}"
}

# ─── Validation ───────────────────────────────────────────

validate_project_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "Project name may only contain letters, numbers, underscores and hyphens"
}
