#!/usr/bin/env bash
#
# walrus status - show overview of all registered projects

cmd_status() {
  banner

  local projects
  projects=$(list_all_projects)

  if [[ -z "$projects" ]]; then
    log_warn "暂无已注册项目"
    echo ""
    log_dim "开始使用: walrus init"
    echo ""
    return
  fi

  # R2 connection
  local r2_ok=true
  r2_check_connection || r2_ok=false
  if $r2_ok; then
    log_ok "R2 连接正常"
  else
    log_err "R2 连接失败"
  fi

  # Service status
  if systemctl is-active walrus-sync.timer &>/dev/null; then
    log_ok "同步服务运行中"
  else
    log_warn "同步服务未运行 ${C_DIM}(walrus service start)${C_RESET}"
  fi
  echo ""

  printf " ${C_BOLD}项目列表${C_RESET}\n\n"

  while read -r proj; do
    # shellcheck disable=SC1090
    source "${WALRUS_CONF_DIR}/${proj}.conf"

    # Container
    local c_status
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
      c_status="${C_GREEN}●${C_RESET} 运行中"
    else
      c_status="${C_RED}●${C_RESET} 已停止"
    fi

    # Local backups
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
      latest_info="${C_DIM}无${C_RESET}"
    fi

    # R2
    local r2_count="-"
    $r2_ok && r2_count=$(rclone lsf "${R2_REMOTE}:${R2_BUCKET}/${proj}/base/" 2>/dev/null | wc -l | xargs)

    # WAL
    local wal_count
    wal_count=$(find "${WALRUS_DATA_DIR}/wal/${proj}" -type f 2>/dev/null | wc -l | xargs)

    printf "  ${C_BOLD}%s${C_RESET}\n" "$proj"
    printf "    %-12s %b  ${C_DIM}|${C_RESET}  %s@%s\n" "状态" "$c_status" "$DB_USER" "$DB_NAME"
    printf "    %-12s 本地 %s 个  ${C_DIM}|${C_RESET}  R2 %s 个\n" "备份" "$local_count" "$r2_count"
    printf "    %-12s %b\n" "最新" "$latest_info"
    printf "    %-12s %s 个待同步  ${C_DIM}|${C_RESET}  保留 %s 天  ${C_DIM}|${C_RESET}  限速 %s\n" "WAL" "$wal_count" "$DAYS_KEEP" "$BWLIMIT"
    echo ""
  done <<< "$projects"
}
