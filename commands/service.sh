#!/usr/bin/env bash
#
# walrus service - manage systemd services
#
# Creates two systemd units per project:
#   walrus-sync@<project>.timer   - WAL sync every 5 minutes
#   walrus-backup@<project>.timer - Full backup daily at 03:00
#
# Also provides: walrus service [start|stop|status|enable|disable]

readonly SYSTEMD_DIR="/etc/systemd/system"

# ─── Internal: Install service units for a project ────────

_install_service() {
  local project="$1"

  # Skip if systemd is not available
  if ! command -v systemctl &>/dev/null; then
    log_warn "systemd 不可用，已跳过服务安装 (使用 cron 作为后备)"
    return
  fi

  log_run "安装 systemd 服务..."

  # ── Sync service (oneshot) ──
  cat > "${SYSTEMD_DIR}/walrus-sync@.service" <<'UNIT'
[Unit]
Description=walrus WAL sync for %i
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/walrus sync --project %i
StandardOutput=append:/opt/walrus/logs/%i/sync.log
StandardError=append:/opt/walrus/logs/%i/sync.log
UNIT

  # ── Sync timer ──
  cat > "${SYSTEMD_DIR}/walrus-sync@${project}.timer" <<UNIT
[Unit]
Description=walrus WAL sync timer for ${project}

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
UNIT

  # ── Backup service (oneshot) ──
  cat > "${SYSTEMD_DIR}/walrus-backup@.service" <<'UNIT'
[Unit]
Description=walrus full backup for %i
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/walrus backup --project %i
StandardOutput=append:/opt/walrus/logs/%i/backup.log
StandardError=append:/opt/walrus/logs/%i/backup.log
TimeoutStartSec=3600
UNIT

  # ── Backup timer ──
  cat > "${SYSTEMD_DIR}/walrus-backup@${project}.timer" <<UNIT
[Unit]
Description=walrus daily backup timer for ${project}

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
UNIT

  # Reload and enable
  systemctl daemon-reload
  systemctl enable --now "walrus-sync@${project}.timer" >/dev/null 2>&1
  systemctl enable --now "walrus-backup@${project}.timer" >/dev/null 2>&1

  log_ok "systemd 服务已安装并启动"
  log_dim "WAL 同步: walrus-sync@${project}.timer (每 5 分钟)"
  log_dim "全量备份: walrus-backup@${project}.timer (每天 03:00)"
  echo ""
}

# ─── Internal: Remove service units for a project ────────

_remove_service() {
  local project="$1"

  command -v systemctl &>/dev/null || return

  systemctl disable --now "walrus-sync@${project}.timer" 2>/dev/null || true
  systemctl disable --now "walrus-backup@${project}.timer" 2>/dev/null || true

  rm -f "${SYSTEMD_DIR}/walrus-sync@${project}.timer"
  rm -f "${SYSTEMD_DIR}/walrus-backup@${project}.timer"

  # Only remove template units if no other projects use them
  local remaining
  remaining=$(list_all_projects | grep -v "^${project}$" | head -1 || true)
  if [[ -z "$remaining" ]]; then
    rm -f "${SYSTEMD_DIR}/walrus-sync@.service"
    rm -f "${SYSTEMD_DIR}/walrus-backup@.service"
  fi

  systemctl daemon-reload 2>/dev/null || true
}

# ─── Command: walrus service ─────────────────────────────

cmd_service() {
  local action="${1:-status}"
  shift || true

  command -v systemctl &>/dev/null || die "systemd 不可用"
  require_root "service"

  case "$action" in
    start)
      log_run "启动所有 walrus 服务..."
      while read -r proj; do
        systemctl start "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl start "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "$proj"
      done <<< "$(list_all_projects)"
      ;;

    stop)
      log_run "停止所有 walrus 服务..."
      while read -r proj; do
        systemctl stop "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl stop "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "$proj"
      done <<< "$(list_all_projects)"
      ;;

    enable)
      while read -r proj; do
        systemctl enable --now "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl enable --now "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "已启用: $proj"
      done <<< "$(list_all_projects)"
      ;;

    disable)
      while read -r proj; do
        systemctl disable --now "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl disable --now "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "已禁用: $proj"
      done <<< "$(list_all_projects)"
      ;;

    status)
      printf "\n ${C_BOLD}walrus 服务状态${C_RESET}\n\n"

      local projects
      projects=$(list_all_projects)
      [[ -n "$projects" ]] || { log_warn "暂无注册项目"; return; }

      while read -r proj; do
        printf "  ${C_BOLD}%s${C_RESET}\n" "$proj"

        # Sync timer
        local sync_status sync_next
        if systemctl is-active "walrus-sync@${proj}.timer" &>/dev/null; then
          sync_status="${C_GREEN}●${C_RESET} 活跃"
          sync_next=$(systemctl show "walrus-sync@${proj}.timer" --property=NextElapseUSecRealtime --value 2>/dev/null | head -1)
          [[ -n "$sync_next" ]] && sync_next=" → 下次: ${C_DIM}${sync_next}${C_RESET}"
        else
          sync_status="${C_RED}●${C_RESET} 未运行"
          sync_next=""
        fi
        printf "    WAL 同步:   %b%b\n" "$sync_status" "$sync_next"

        # Backup timer
        local backup_status backup_next
        if systemctl is-active "walrus-backup@${proj}.timer" &>/dev/null; then
          backup_status="${C_GREEN}●${C_RESET} 活跃"
          backup_next=$(systemctl show "walrus-backup@${proj}.timer" --property=NextElapseUSecRealtime --value 2>/dev/null | head -1)
          [[ -n "$backup_next" ]] && backup_next=" → 下次: ${C_DIM}${backup_next}${C_RESET}"
        else
          backup_status="${C_RED}●${C_RESET} 未运行"
          backup_next=""
        fi
        printf "    全量备份:  %b%b\n" "$backup_status" "$backup_next"
        echo ""
      done <<< "$projects"
      ;;

    -h|--help|help)
      cat <<USAGE
用法: walrus service <action>

  start     启动所有项目的备份服务
  stop      停止所有项目的备份服务
  enable    启用并开机自启
  disable   禁用服务
  status    查看服务运行状态 (默认)
USAGE
      ;;

    *)
      die "未知操作: $action (可选: start|stop|enable|disable|status)"
      ;;
  esac
}
