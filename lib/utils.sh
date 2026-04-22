#!/usr/bin/env bash
#
# walrus - utilities
# Interactive prompts, checks, and common helpers

# ─── Interactive Prompts ──────────────────────────────────

# Prompt with default value → result in REPLY
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

# Prompt for secret (no echo) → result in REPLY
ask_secret() {
  local prompt="$1"
  printf "  ${C_CYAN}?${C_RESET} %s: " "$prompt"
  read -rs REPLY
  echo ""
}

# Yes/no confirmation → returns 0 (yes) or 1 (no)
confirm() {
  local prompt="$1"
  printf "  ${C_CYAN}?${C_RESET} %s ${C_DIM}(y/n)${C_RESET}: " "$prompt"
  local ans
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ─── Checks ───────────────────────────────────────────────

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 用户运行: sudo walrus $*"
}

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' 未安装"
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

# Validate project name: alphanumeric, dash, underscore only
validate_project_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "项目名称只允许字母、数字、下划线和短横线"
}
