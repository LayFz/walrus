#!/usr/bin/env bash
#
# walrus remove - unregister a project

cmd_remove() {
  local project_arg="" purge=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      --purge)   purge=true; shift;;
      -h|--help) echo "Usage: walrus remove --project <name> [--purge]"; return;;
      *) shift;;
    esac
  done

  [[ -n "$project_arg" ]] || die "Please specify --project"

  local conf="${WALRUS_CONF_DIR}/${project_arg}.conf"
  [[ -f "$conf" ]] || die "Project '${project_arg}' does not exist"

  if ! confirm "Remove project '${project_arg}'?"; then
    echo "  Cancelled"
    return
  fi

  # Load config before deleting (for purge)
  local saved_remote="" saved_bucket=""
  if $purge; then
    # shellcheck disable=SC1090
    source "$conf"
    saved_remote="$R2_REMOTE"
    saved_bucket="$R2_BUCKET"
  fi

  # Remove cron
  local cron_tag="# walrus:${project_arg}"
  local tmpfile
  tmpfile=$(mktemp_tracked)
  crontab -l 2>/dev/null | grep -v "$cron_tag" > "$tmpfile" || true
  crontab "$tmpfile"

  # Remove systemd units
  _remove_service "$project_arg"

  # Remove local data
  rm -rf "${WALRUS_DATA_DIR:?}/base/${project_arg}"
  rm -rf "${WALRUS_DATA_DIR:?}/wal/${project_arg}"
  rm -rf "${WALRUS_LOG_DIR:?}/${project_arg}"
  rm -f "$conf"

  log_ok "Project '${project_arg}' removed"

  if $purge && [[ -n "$saved_remote" ]] && [[ -n "$saved_bucket" ]]; then
    log_run "Purging R2 backups..."
    rclone purge "${saved_remote}:${saved_bucket}/${project_arg}/" 2>/dev/null || true
    log_ok "R2 backups purged"
  else
    log_dim "R2 backups retained (add --purge to delete)"
  fi
}
