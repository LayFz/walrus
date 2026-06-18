#!/usr/bin/env bash
#
# walrus restore - restore database from R2 backup
# Restores to a local Docker container for verification
#
# Works with just the R2 key: if there is no local project config (e.g. a
# brand-new machine after `walrus config`), it bootstraps everything it needs
# straight from R2 — no need to copy any config file across machines.

# Does a local config exist for this project (or any, when none requested)?
_restore_have_conf() {
  local p="$1"
  if [[ -n "$p" ]]; then
    [[ -f "${WALRUS_CONF_DIR}/${p}.conf" ]]
  else
    local f
    for f in "${WALRUS_CONF_DIR}"/*.conf; do
      [[ -f "$f" ]] && return 0
    done
    return 1
  fi
}

# Bootstrap project metadata straight from R2 — no local config needed.
# Sets: PROJECT, R2_REMOTE, R2_BUCKET, and best-effort DB_USER/DB_NAME/PG_MAJOR.
_restore_bootstrap() {
  local p="$1" bucket="$2"

  require_cmd rclone
  r2_is_configured || die "Remote storage not configured — run 'walrus config' first"

  R2_REMOTE="$WALRUS_R2_REMOTE"
  R2_BUCKET="${bucket:-$(r2_default_bucket)}"

  # Discover the project when one wasn't specified.
  if [[ -z "$p" ]]; then
    local projects
    projects=$(rclone lsf "${R2_REMOTE}:${R2_BUCKET}/" 2>/dev/null | sed 's:/*$::' | grep -v '^$' || true)
    [[ -n "$projects" ]] || die "No projects found in bucket '${R2_BUCKET}' (use --bucket to choose another)"

    printf " ${C_DIM}Projects on R2 (bucket: %s):${C_RESET}\n" "$R2_BUCKET"
    local i=1
    while read -r pr; do
      printf "   ${C_CYAN}%d)${C_RESET} %s\n" "$i" "$pr"
      i=$((i + 1))
    done <<< "$projects"
    echo ""
    ask "Select project number" "1"
    [[ "$REPLY" =~ ^[0-9]+$ ]] || die "Invalid selection"
    p=$(echo "$projects" | sed -n "${REPLY}p")
    [[ -n "$p" ]] || die "Invalid selection"
    echo ""
  fi

  # Same constraint the conf path enforces at init time — keeps the name out of
  # path traversal when it flows into work_dir / rm -rf / tar / docker.
  validate_project_name "$p"
  PROJECT="$p"

  # Defaults for vars referenced elsewhere (keeps things safe under `set -u`).
  MODE="r2"; CONTAINER=""; DB_HOST=""; DB_PORT=""
  DB_USER=""; DB_NAME=""; DB_PASS=""; PG_MAJOR=""

  # Newer backups upload a small, non-secret manifest. Use it when present so
  # the connect hints and the empty-backup check are nicer; old backups still
  # restore fine without it (PG version is read from the backup itself).
  local manifest
  manifest=$(rclone cat "${R2_REMOTE}:${R2_BUCKET}/${PROJECT}/walrus.conf" 2>/dev/null || true)
  if [[ -n "$manifest" ]]; then
    DB_USER=$(printf '%s\n' "$manifest"  | sed -n 's/^DB_USER=//p'  | tr -d '"\r' | head -1)
    DB_NAME=$(printf '%s\n' "$manifest"  | sed -n 's/^DB_NAME=//p'  | tr -d '"\r' | head -1)
    PG_MAJOR=$(printf '%s\n' "$manifest" | sed -n 's/^PG_MAJOR=//p' | tr -dc '0-9')
  fi
}

cmd_restore() {
  local project_arg="" db_pass="" target_time="" dl_bwlimit="50M" bucket_arg=""
  local interactive=true

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)     project_arg="$2"; shift 2;;
      --password)    db_pass="$2"; interactive=false; shift 2;;
      --target-time) target_time="$2"; shift 2;;
      --bwlimit)     dl_bwlimit="$2"; shift 2;;
      --bucket)      bucket_arg="$2"; shift 2;;
      -h|--help)
        echo "Usage: walrus restore [--project <name>] [--bucket <name>] [--password <pass>] [--target-time \"2026-04-23 14:30:00+08\"]"
        return;;
      *) shift;;
    esac
  done

  banner

  # Resolve the project: prefer a local config, otherwise bootstrap straight
  # from R2 so a fresh machine can restore with just the key.
  local from_r2=false
  if _restore_have_conf "$project_arg"; then
    resolve_project "$project_arg"
  else
    _restore_bootstrap "$project_arg" "$bucket_arg"
    from_r2=true
  fi

  printf " ${C_BOLD}Restore project: %s${C_RESET}\n\n" "$PROJECT"

  local mode_label
  if $from_r2; then
    mode_label="R2 (${R2_REMOTE}:${R2_BUCKET}/${PROJECT})"
  elif [[ "$MODE" == "docker" ]]; then
    mode_label="Docker (${CONTAINER})"
  else
    mode_label="${DB_HOST}:${DB_PORT}"
  fi
  log_dim "Source: ${mode_label} | Restore via: local Docker container"
  echo ""

  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}"

  # No password is needed: the restored cluster keeps the original credentials.

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
    [[ "$REPLY" =~ ^[0-9]+$ ]] || die "Invalid selection"
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
  local work_dir="${WALRUS_DATA_DIR}/restore/${PROJECT}"
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

  [[ -s "${work_dir}/pgdata/PG_VERSION" ]] || \
    die "Extracted backup has no PG_VERSION — the download may be corrupt or truncated"

  # Derive the PG major version from the backup when config didn't provide it.
  if [[ -z "${PG_MAJOR:-}" ]]; then
    PG_MAJOR=$(tr -dc '0-9' < "${work_dir}/pgdata/PG_VERSION")
  fi

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

  # Best-effort: the official image (running as root) fixes ownership itself,
  # so this must not abort the restore when run as a non-root user.
  chown -R 999:999 "${work_dir}/pgdata" 2>/dev/null || true
  log_ok "Recovery configured"

  # Launch
  require_cmd docker

  local restore_name="walrus_${PROJECT}_restore"
  docker rm -f "$restore_name" 2>/dev/null || true

  local pg_image="postgres:${PG_MAJOR:-16}"
  log_run "Starting database (${pg_image})..."
  docker run -d \
    --name "$restore_name" \
    -v "${work_dir}/pgdata:/var/lib/postgresql/data" \
    -e POSTGRES_USER="${DB_USER:-postgres}" \
    -e POSTGRES_PASSWORD="${db_pass:-walrus_restore}" \
    -p 15432:5432 \
    "$pg_image" >/dev/null

  # Wait for ready (role-agnostic: pg_isready needs no credentials)
  log_run "Waiting for database to be ready..."
  local attempts=0
  while [[ $attempts -lt 30 ]]; do
    if docker exec "$restore_name" pg_isready -q 2>/dev/null; then
      break
    fi
    sleep 1
    attempts=$((attempts + 1))
  done

  echo ""
  if docker exec "$restore_name" pg_isready -q 2>/dev/null; then
    # Sanity-check the data actually came back, so an empty backup can't
    # masquerade as a successful restore.
    local userdb_count tbls=""
    userdb_count=$(find "${work_dir}/pgdata/base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
      | awk -F/ '{ if ($NF+0 >= 16384) c++ } END { print c+0 }' || true)
    userdb_count=${userdb_count:-0}
    # A live table count is only meaningful for an immediate restore; during a
    # point-in-time restore the server accepts connections before replay has
    # reached the target, so the count would be misleading.
    if [[ -z "$target_time" && -n "${DB_USER:-}" && -n "${DB_NAME:-}" ]]; then
      tbls=$(docker exec "$restore_name" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','p') AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast');" 2>/dev/null | tr -d '[:space:]' || true)
    fi

    printf " ${C_GREEN}${C_BOLD}Restore successful!${C_RESET}\n\n"
    # Trust the live table count when we have one; otherwise fall back to
    # "are there any user databases on disk?".
    local looks_empty=false
    if [[ -n "$tbls" ]]; then
      if [[ "$tbls" == "0" ]]; then looks_empty=true; fi
    elif [[ "$userdb_count" -eq 0 ]]; then
      looks_empty=true
    fi
    if $looks_empty; then
      log_warn "Restored cluster has NO user data (looks EMPTY) — pick an earlier/larger backup if you expected data"
      echo ""
    elif [[ -n "$tbls" ]]; then
      log_dim "User tables found: ${tbls}"
    fi
    if [[ -n "${DB_USER:-}" && -n "${DB_NAME:-}" ]]; then
      log_dim "Connect:  docker exec -it ${restore_name} psql -U ${DB_USER} -d ${DB_NAME}"
    else
      log_dim "Connect:  docker exec -it ${restore_name} psql -U <db_user> -d <db_name>   (list dbs: psql -U <db_user> -l)"
    fi
    log_dim "Port:     15432"
    log_dim "Cleanup:  docker rm -f ${restore_name} && rm -rf ${work_dir}"
  else
    log_warn "Database may still be recovering"
    log_dim "View logs: docker logs -f ${restore_name}"
  fi
  echo ""
}
