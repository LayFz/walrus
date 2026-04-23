#!/usr/bin/env bash
#
# walrus - lock management
# Prevents concurrent backup operations on the same project

acquire_lock() {
  local project="$1"
  local lockfile="${WALRUS_LOCK_DIR}/${project}.lock"
  mkdir -p "${WALRUS_LOCK_DIR}"

  if [[ -f "$lockfile" ]]; then
    local pid
    pid=$(<"$lockfile")
    if kill -0 "$pid" 2>/dev/null; then
      die "Project '${project}' has a running task (PID: ${pid})"
    fi
    rm -f "$lockfile"
  fi

  echo $$ > "$lockfile"
  _WALRUS_TMPFILES+=("$lockfile")
}
