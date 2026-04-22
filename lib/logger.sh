#!/usr/bin/env bash
#
# walrus - logging
# Structured log output with icons and colors

log_ok()   { printf " ${C_GREEN}✓${C_RESET} %s\n" "$1"; }
log_warn() { printf " ${C_YELLOW}!${C_RESET} %s\n" "$1"; }
log_err()  { printf " ${C_RED}✗${C_RESET} %s\n" "$1" >&2; }
log_run()  { printf " ${C_CYAN}→${C_RESET} %s\n" "$1"; }
log_dim()  { printf "   ${C_DIM}%s${C_RESET}\n" "$1"; }

# Fatal error — log and exit
die() {
  log_err "$1"
  exit "${2:-1}"
}

# Timestamped log for background tasks (backup, sync)
# Usage: ts_log "PROJECT" "message" "/path/to/logfile"
ts_log() {
  local project="$1" message="$2" logfile="${3:-}"
  local line
  line=$(printf "[%s][%s] %s" "$(date '+%Y-%m-%d %H:%M:%S')" "$project" "$message")
  if [[ -n "$logfile" ]]; then
    echo "$line" | tee -a "$logfile"
  else
    echo "$line"
  fi
}
