#!/usr/bin/env bash
#
# walrus service - manage systemd services
#
# Creates two systemd units per project:
#   walrus-sync@<project>.timer   - WAL sync every 5 minutes
#   walrus-backup@<project>.timer - Full backup daily at 03:00

readonly SYSTEMD_DIR="/etc/systemd/system"

# ─── Internal: Install service units for a project ────────

_install_service() {
  local project="$1"

  if ! command -v systemctl &>/dev/null; then
    log_warn "systemd not available, skipping automatic backup service"
    log_dim "You can add a crontab manually: walrus backup --project ${project}"
    return
  fi
  if [[ "$(id -u)" -ne 0 ]]; then
    log_warn "Not running as root, skipping systemd service installation"
    log_dim "Manual backup: walrus backup --project ${project}"
    log_dim "Or run walrus init as root to install automatic backup service"
    return
  fi

  log_run "Installing systemd services..."

  cat > "${SYSTEMD_DIR}/walrus-sync@.service" <<'UNIT'
[Unit]
Description=walrus WAL sync for %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/walrus sync --project %i
StandardOutput=append:/opt/walrus/logs/%i/sync.log
StandardError=append:/opt/walrus/logs/%i/sync.log
UNIT

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

  cat > "${SYSTEMD_DIR}/walrus-backup@.service" <<'UNIT'
[Unit]
Description=walrus full backup for %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/walrus backup --project %i
StandardOutput=append:/opt/walrus/logs/%i/backup.log
StandardError=append:/opt/walrus/logs/%i/backup.log
TimeoutStartSec=3600
UNIT

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

  systemctl daemon-reload
  systemctl enable --now "walrus-sync@${project}.timer" >/dev/null 2>&1
  systemctl enable --now "walrus-backup@${project}.timer" >/dev/null 2>&1

  log_ok "systemd services installed and started"
  log_dim "WAL sync:    walrus-sync@${project}.timer (every 5 min)"
  log_dim "Full backup: walrus-backup@${project}.timer (daily 03:00)"
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

  command -v systemctl &>/dev/null || die "systemd not available"
  require_root "service"

  case "$action" in
    start)
      log_run "Starting all walrus services..."
      while read -r proj; do
        systemctl start "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl start "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "$proj"
      done <<< "$(list_all_projects)"
      ;;

    stop)
      log_run "Stopping all walrus services..."
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
        log_ok "Enabled: $proj"
      done <<< "$(list_all_projects)"
      ;;

    disable)
      while read -r proj; do
        systemctl disable --now "walrus-sync@${proj}.timer" 2>/dev/null
        systemctl disable --now "walrus-backup@${proj}.timer" 2>/dev/null
        log_ok "Disabled: $proj"
      done <<< "$(list_all_projects)"
      ;;

    status)
      printf "\n ${C_BOLD}walrus Service Status${C_RESET}\n\n"

      local projects
      projects=$(list_all_projects)
      [[ -n "$projects" ]] || { log_warn "No registered projects"; return; }

      while read -r proj; do
        printf "  ${C_BOLD}%s${C_RESET}\n" "$proj"

        local sync_status sync_next
        if systemctl is-active "walrus-sync@${proj}.timer" &>/dev/null; then
          sync_status="${C_GREEN}●${C_RESET} Active"
          sync_next=$(systemctl show "walrus-sync@${proj}.timer" --property=NextElapseUSecRealtime --value 2>/dev/null | head -1)
          [[ -n "$sync_next" ]] && sync_next=" -> Next: ${C_DIM}${sync_next}${C_RESET}" || true
        else
          sync_status="${C_RED}●${C_RESET} Inactive"
          sync_next=""
        fi
        printf "    WAL sync:    %b%b\n" "$sync_status" "$sync_next"

        local backup_status backup_next
        if systemctl is-active "walrus-backup@${proj}.timer" &>/dev/null; then
          backup_status="${C_GREEN}●${C_RESET} Active"
          backup_next=$(systemctl show "walrus-backup@${proj}.timer" --property=NextElapseUSecRealtime --value 2>/dev/null | head -1)
          [[ -n "$backup_next" ]] && backup_next=" -> Next: ${C_DIM}${backup_next}${C_RESET}" || true
        else
          backup_status="${C_RED}●${C_RESET} Inactive"
          backup_next=""
        fi
        printf "    Full backup: %b%b\n" "$backup_status" "$backup_next"
        echo ""
      done <<< "$projects"
      ;;

    -h|--help|help)
      cat <<USAGE
Usage: walrus service <action>

  start     Start all backup services
  stop      Stop all backup services
  enable    Enable and start on boot
  disable   Disable services
  status    Show service status (default)
USAGE
      ;;

    *)
      die "Unknown action: $action (options: start|stop|enable|disable|status)"
      ;;
  esac
}
