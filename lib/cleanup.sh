#!/usr/bin/env bash
#
# walrus - cleanup & signal handling
# Manages temp files and ensures clean exit

declare -a _WALRUS_TMPFILES=()

# Register a temp file for cleanup on exit
mktemp_tracked() {
  local f
  f=$(mktemp "${TMPDIR:-/tmp}/walrus.XXXXXX")
  _WALRUS_TMPFILES+=("$f")
  echo "$f"
}

# Remove all registered temp files
_walrus_cleanup() {
  local f
  for f in "${_WALRUS_TMPFILES[@]+"${_WALRUS_TMPFILES[@]}"}"; do
    rm -f "$f" 2>/dev/null || true
  done
}

# Setup handlers
trap _walrus_cleanup EXIT
trap 'echo ""; log_warn "中断"; exit 130' INT TERM
