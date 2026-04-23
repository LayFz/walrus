#!/usr/bin/env bash
#
# walrus restore - restore database from R2 backup
# Restores to a local Docker container for verification

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
        echo "Usage: walrus restore [--project <name>] [--password <pass>] [--target-time \"2026-04-23 14:30:00+08\"]"
        return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  banner
  printf " ${C_BOLD}Restore project: %s${C_RESET}\n\n" "$PROJECT"

  local mode_label
  if [[ "$MODE" == "docker" ]]; then
    mode_label="Docker (${CONTAINER})"
  else
    mode_label="${DB_HOST}:${DB_PORT}"
  fi
  log_dim "Source: ${mode_label} | Restore via: local Docker container"
  echo ""

  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}"

  # Interactive password
  if [[ -z "$db_pass" ]]; then
    ask_secret "Database password"
    db_pass="$REPLY"
    [[ -n "$db_pass" ]] || die "Password cannot be empty"
    echo ""
  fi

  # List backups
  log_run "Finding available backups..."
  local backups
  backups=$(rclone lsf "${r2_path}/base/" 2>/dev/null | sort)
  [[ -n "$backups" ]] || die "No backups found for ${PROJECT} on R2"

  echo ""
  printf " ${C_DIM}Available backups:${C_RESET}\n"
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
    ask "Select backup number (default: latest)" "$((i - 1))"
    latest=$(echo "$backups" | sed -n "${REPLY}p")
    [[ -n "$latest" ]] || die "Invalid selection"

    if [[ -z "$target_time" ]]; then
      echo ""
      ask "Restore to specific point in time? (leave empty for latest)" ""
      target_time="$REPLY"
    fi
  fi

  echo ""

  # Download & restore
  local work_dir="/opt/walrus_restore/${PROJECT}"
  rm -rf "$work_dir"
  mkdir -p "${work_dir}"/{base,wal,pgdata}

  log_run "Downloading base backup: ${latest}"
  rclone copy "${r2_path}/base/${latest}" "${work_dir}/base/" --bwlimit "$dl_bwlimit" --progress
  log_ok "Download complete"

  log_run "Downloading WAL..."
  rclone copy "${r2_path}/wal/" "${work_dir}/wal/" --bwlimit "$dl_bwlimit" --progress
  log_ok "WAL download complete"

  log_run "Extracting..."
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
  log_ok "Recovery configured"

  # Launch
  require_cmd docker

  local restore_name="walrus_${PROJECT}_restore"
  docker rm -f "$restore_name" 2>/dev/null || true

  log_run "Starting database..."
  docker run -d \
    --name "$restore_name" \
    -v "${work_dir}/pgdata:/var/lib/postgresql/data" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$db_pass" \
    -p 15432:5432 \
    postgres:16 >/dev/null

  # Wait for ready
  log_run "Waiting for database to be ready..."
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
    printf " ${C_GREEN}${C_BOLD}Restore successful!${C_RESET}\n\n"
    log_dim "Connect:  docker exec -it ${restore_name} psql -U ${DB_USER} -d ${DB_NAME}"
    log_dim "Port:     15432"
    log_dim "Cleanup:  docker rm -f ${restore_name} && rm -rf ${work_dir}"
  else
    log_warn "Database may still be recovering"
    log_dim "View logs: docker logs -f ${restore_name}"
  fi
  echo ""
}
