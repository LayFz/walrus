#!/usr/bin/env bash
#
# walrus remove - unregister a project

cmd_remove() {
  local project_arg="" purge=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      --purge)   purge=true; shift;;
      -h|--help) echo "用法: walrus remove --project <名称> [--purge]"; return;;
      *) shift;;
    esac
  done

  [[ -n "$project_arg" ]] || die "请指定 --project"

  local conf="${WALRUS_CONF_DIR}/${project_arg}.conf"
  [[ -f "$conf" ]] || die "项目 '${project_arg}' 不存在"

  if ! confirm "确定移除项目 '${project_arg}'?"; then
    echo "  取消"
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

  # Remove systemd units for this project
  _remove_service "$project_arg"

  # Remove local data
  rm -rf "${WALRUS_DATA_DIR:?}/base/${project_arg}"
  rm -rf "${WALRUS_DATA_DIR:?}/wal/${project_arg}"
  rm -rf "${WALRUS_LOG_DIR:?}/${project_arg}"
  rm -f "$conf"

  log_ok "项目 '${project_arg}' 已移除"

  if $purge && [[ -n "$saved_remote" ]] && [[ -n "$saved_bucket" ]]; then
    log_run "清除 R2 备份..."
    rclone purge "${saved_remote}:${saved_bucket}/${project_arg}/" 2>/dev/null || true
    log_ok "R2 备份已清除"
  else
    log_dim "R2 备���已保留 (添加 --purge 同时删除)"
  fi
}
