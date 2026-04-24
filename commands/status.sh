#!/usr/bin/env bash
#
# walrus status - show overview of all registered projects

cmd_status() {
  banner

  local projects
  projects=$(list_all_projects)

  if [[ -z "$projects" ]]; then
    log_warn "No projects registered"
    echo ""
    log_dim "Get started: walrus init"
    echo ""
    return
  fi

  # R2 connection
  local r2_ok=true
  r2_check_connection || r2_ok=false
  if $r2_ok; then
    log_ok "R2 connection OK"
  else
    log_err "R2 connection failed"
  fi

  # Service status
  if command -v systemctl &>/dev/null; then
    local any_active=false
    while read -r proj; do
      if systemctl is-active "walrus-sync@${proj}.timer" &>/dev/null; then
        any_active=true
        break
      fi
    done <<< "$projects"
    if $any_active; then
      log_ok "Sync service running"
    else
      log_warn "Sync service not running ${C_DIM}(walrus service start)${C_RESET}"
    fi
  fi
  echo ""

  printf " ${C_BOLD}Projects${C_RESET}\n\n"

  while read -r proj; do
    load_project_conf "$proj"

    local src_status
    if pg_test_connection 2>/dev/null; then
      if [[ "$MODE" == "docker" ]]; then
        src_status="${C_GREEN}●${C_RESET} Running ${C_DIM}(Docker: ${CONTAINER})${C_RESET}"
      else
        src_status="${C_GREEN}●${C_RESET} Running ${C_DIM}(${DB_HOST}:${DB_PORT})${C_RESET}"
      fi
    else
      if [[ "$MODE" == "docker" ]]; then
        src_status="${C_RED}●${C_RESET} Stopped ${C_DIM}(Docker: ${CONTAINER})${C_RESET}"
      else
        src_status="${C_RED}●${C_RESET} Unreachable ${C_DIM}(${DB_HOST}:${DB_PORT})${C_RESET}"
      fi
    fi

    local local_count latest_info
    local_count=$(find "${WALRUS_DATA_DIR}/base/${proj}" -name "base_*.tar.gz" 2>/dev/null | wc -l | xargs)
    local latest_file
    latest_file=$(ls -t "${WALRUS_DATA_DIR}/base/${proj}"/base_*.tar.gz 2>/dev/null | head -1 || true)
    if [[ -n "$latest_file" ]]; then
      local fsize fname fdate
      fsize=$(du -sh "$latest_file" | cut -f1)
      fname=$(basename "$latest_file")
      fdate=$(echo "$fname" | sed 's/base_\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*/\1-\2-\3 \4:\5:\6/')
      latest_info="${fdate}  ${C_DIM}(${fsize})${C_RESET}"
    else
      latest_info="${C_DIM}None${C_RESET}"
    fi

    local r2_count="-"
    if $r2_ok; then
      r2_count=$(rclone lsf "${R2_REMOTE}:${R2_BUCKET}/${proj}/base/" 2>/dev/null | wc -l | xargs)
    fi

    local wal_count
    wal_count=$(find "${WALRUS_DATA_DIR}/wal/${proj}" -type f 2>/dev/null | wc -l | xargs)

    printf "  ${C_BOLD}%s${C_RESET}\n" "$proj"
    printf "    %-12s %b\n" "Status" "$src_status"
    printf "    %-12s %s@%s\n" "Database" "$DB_USER" "$DB_NAME"
    printf "    %-12s Local %s  ${C_DIM}|${C_RESET}  R2 %s\n" "Backups" "$local_count" "$r2_count"
    printf "    %-12s %b\n" "Latest" "$latest_info"
    printf "    %-12s %s pending  ${C_DIM}|${C_RESET}  Retain %s days  ${C_DIM}|${C_RESET}  Rate limit %s\n" "WAL" "$wal_count" "$DAYS_KEEP" "$BWLIMIT"
    echo ""
  done <<< "$projects"
}
