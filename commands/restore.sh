#!/usr/bin/env bash
#
# walrus restore - restore database from R2 backup

cmd_restore() {
  local project_arg="" db_pass="" target_time="" dl_bwlimit="50M"
  local interactive=true

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)     project_arg="$2"; shift 2;;
      --password)    db_pass="$2"; interactive=false; shift 2;;
      --target-time) target_time="$2"; shift 2;;
      --bwlimit)     dl_bwlimit="$2"; shift 2;;
      -h|--help)
        echo "用法: walrus restore [--project <名称>] [--password <密码>] [--target-time \"2026-04-22 14:30:00+08\"]"
        return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  banner
  printf " ${C_BOLD}恢复项目: %s${C_RESET}\n\n" "$PROJECT"

  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}"

  # Interactive password
  if [[ -z "$db_pass" ]]; then
    ask_secret "数据库密码"
    db_pass="$REPLY"
    [[ -n "$db_pass" ]] || die "密码不能为空"
    echo ""
  fi

  # List backups
  log_run "查找可用备份..."
  local backups
  backups=$(rclone lsf "${r2_path}/base/" 2>/dev/null | sort)
  [[ -n "$backups" ]] || die "R2 上没有找到 ${PROJECT} 的备份"

  echo ""
  printf " ${C_DIM}可用备份:${C_RESET}\n"
  local i=1
  while read -r f; do
    local fdate
    fdate=$(echo "$f" | sed 's/base_\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*/\1-\2-\3 \4:\5:\6/')
    printf "   ${C_CYAN}%d)${C_RESET} %s ${C_DIM}(%s)${C_RESET}\n" "$i" "$fdate" "$f"
    i=$((i + 1))
  done <<< "$backups"

  local latest
  latest=$(echo "$backups" | tail -1)

  if $interactive; then
    echo ""
    ask "选择备份编号 (默认最新)" "$((i - 1))"
    latest=$(echo "$backups" | sed -n "${REPLY}p")
    [[ -n "$latest" ]] || die "无效选择"

    if [[ -z "$target_time" ]]; then
      echo ""
      ask "恢复到指定时间点? 留空则恢复到最新" ""
      target_time="$REPLY"
    fi
  fi

  echo ""

  # Download & restore
  local work_dir="/opt/walrus_restore/${PROJECT}"
  rm -rf "$work_dir"
  mkdir -p "${work_dir}"/{base,wal,pgdata}

  log_run "下载 base backup: ${latest}"
  rclone copy "${r2_path}/base/${latest}" "${work_dir}/base/" --bwlimit "$dl_bwlimit" --progress
  log_ok "下载完成"

  log_run "下载 WAL..."
  rclone copy "${r2_path}/wal/" "${work_dir}/wal/" --bwlimit "$dl_bwlimit" --progress
  log_ok "WAL 下载完成"

  log_run "解压..."
  tar xzf "${work_dir}/base/${latest}" -C "${work_dir}/pgdata/"

  mkdir -p "${work_dir}/pgdata/pg_wal"
  cp "${work_dir}"/wal/* "${work_dir}/pgdata/pg_wal/" 2>/dev/null || true

  # Recovery config
  touch "${work_dir}/pgdata/recovery.signal"

  local restore_conf="restore_command = 'cp /var/lib/postgresql/data/pg_wal/%f %p'"
  if [[ -n "$target_time" ]]; then
    restore_conf="${restore_conf}
recovery_target_time = '${target_time}'"
  else
    restore_conf="${restore_conf}
recovery_target = 'immediate'"
  fi
  echo "$restore_conf" >> "${work_dir}/pgdata/postgresql.auto.conf"

  chown -R 999:999 "${work_dir}/pgdata"
  log_ok "恢复配置完成"

  # Launch
  local restore_name="walrus_${PROJECT}_restore"
  docker rm -f "$restore_name" 2>/dev/null || true

  log_run "启动数据库..."
  docker run -d \
    --name "$restore_name" \
    -v "${work_dir}/pgdata:/var/lib/postgresql/data" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$db_pass" \
    -p 15432:5432 \
    postgres:16 >/dev/null

  # Wait for ready
  log_run "等待数据库就绪..."
  local attempts=0
  while [[ $attempts -lt 30 ]]; do
    if docker exec "$restore_name" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
      break
    fi
    sleep 1
    attempts=$((attempts + 1))
  done

  echo ""
  if docker exec "$restore_name" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    printf " ${C_GREEN}${C_BOLD}恢复成功!${C_RESET} 🦭\n\n"
    log_dim "连接:  docker exec -it ${restore_name} psql -U ${DB_USER} -d ${DB_NAME}"
    log_dim "端口:  15432"
    log_dim "清理:  docker rm -f ${restore_name} && rm -rf ${work_dir}"
  else
    log_warn "数据库可能仍在恢复中"
    log_dim "查看日志: docker logs -f ${restore_name}"
  fi
  echo ""
}
