#!/usr/bin/env bash
#
# walrus - lock management
# Prevents concurrent backup operations on the same project

# Acquire a lock for a project. Dies if already locked by a running process.
acquire_lock() {
  local project="$1"
  local lockfile="${WALRUS_LOCK_DIR}/${project}.lock"
  mkdir -p "${WALRUS_LOCK_DIR}"

  if [[ -f "$lockfile" ]]; then
    local pid
    pid=$(<"$lockfile")
    if kill -0 "$pid" 2>/dev/null; then
      die "项目 '${project}' 有正在运行的任务 (PID: ${pid})"
    fi
    # Stale lock, remove it
    rm -f "$lockfile"
  fi

  echo $$ > "$lockfile"
  _WALRUS_TMPFILES+=("$lockfile")
}
