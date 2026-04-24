#!/usr/bin/env bash
#
# walrus init - register a project and configure automatic backups
# Supports two modes: docker / direct

cmd_init() {
  local PROJECT="" MODE="" CONTAINER="" DB_USER="" DB_NAME="" DB_PASS=""
  local DB_HOST="localhost" DB_PORT="5432"
  local BWLIMIT="" DAYS_KEEP="" R2_BUCKET=""
  local _r2_ak="" _r2_sk="" _r2_ep=""
  local interactive=true from_config=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --from-config)   from_config=true; shift;;
      --project)       PROJECT="$2"; interactive=false; shift 2;;
      --mode)          MODE="$2"; shift 2;;
      --container)     CONTAINER="$2"; shift 2;;
      --host)          DB_HOST="$2"; shift 2;;
      --port)          DB_PORT="$2"; shift 2;;
      --user)          DB_USER="$2"; shift 2;;
      --password)      DB_PASS="$2"; shift 2;;
      --db)            DB_NAME="$2"; shift 2;;
      --r2-access-key) _r2_ak="$2"; shift 2;;
      --r2-secret-key) _r2_sk="$2"; shift 2;;
      --r2-endpoint)   _r2_ep="$2"; shift 2;;
      --bwlimit)       BWLIMIT="$2"; shift 2;;
      --keep)          DAYS_KEEP="$2"; shift 2;;
      --bucket)        R2_BUCKET="$2"; shift 2;;
      -h|--help)       _init_usage; return;;
      *) die "Unknown option: $1";;
    esac
  done

  if ! $from_config; then
    banner
  fi

  # ── R2 setup ──

  if [[ -n "$_r2_ak" ]] && [[ -n "$_r2_sk" ]] && [[ -n "$_r2_ep" ]]; then
    log_run "Configuring R2..."
    ensure_rclone
    _write_remote \
      "provider=Cloudflare" \
      "access_key_id=${_r2_ak}" \
      "secret_access_key=${_r2_sk}" \
      "endpoint=${_r2_ep}" \
      "acl=private" \
      "no_check_bucket=true"
    log_ok "R2 configured"
  fi

  if ! $from_config; then
    if ! r2_is_configured; then
      echo ""
      log_warn "Remote storage not configured"
      echo ""
      if $interactive && confirm "Configure now?"; then
        cmd_config
        return
      else
        die "Please run 'walrus config' to set up remote storage first"
      fi
    fi
    r2_check_connection || die "Remote storage connection failed, run 'walrus config' to reconfigure"
  fi

  # ── Mode selection ──

  if $interactive && [[ -z "$MODE" ]]; then
    printf " ${C_BOLD}Select PostgreSQL deployment mode${C_RESET}\n\n"
    printf "   ${C_CYAN}1)${C_RESET} Docker container  ${C_DIM}PostgreSQL running in Docker${C_RESET}\n"
    printf "   ${C_CYAN}2)${C_RESET} Direct connection  ${C_DIM}Connect via host:port (local or remote)${C_RESET}\n"
    echo ""
    ask "Choose (1/2)" "1"
    case "$REPLY" in
      1) MODE="docker" ;;
      2) MODE="direct" ;;
      *) die "Invalid choice" ;;
    esac
    echo ""
  fi

  MODE="${MODE:-docker}"

  # ── Interactive prompts ──

  if $interactive || [[ -z "$PROJECT" ]]; then
    printf " ${C_BOLD}Register new project${C_RESET}\n\n"

    case "$MODE" in
      docker)
        local pg_containers
        pg_containers=$(docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i "postgres" || true)
        if [[ -n "$pg_containers" ]]; then
          printf " ${C_DIM}Detected PostgreSQL containers:${C_RESET}\n"
          while IFS=$'\t' read -r name image; do
            printf "   ${C_CYAN}•${C_RESET} %s ${C_DIM}(%s)${C_RESET}\n" "$name" "$image"
          done <<< "$pg_containers"
          echo ""
        fi
        [[ -n "$PROJECT" ]]   || { ask "Project name (e.g. myapp)" ""; PROJECT="$REPLY"; }
        [[ -n "$CONTAINER" ]] || { ask "PostgreSQL container name" ""; CONTAINER="$REPLY"; }
        [[ -n "$DB_USER" ]]   || { ask "Database user" "postgres"; DB_USER="$REPLY"; }
        [[ -n "$DB_PASS" ]]   || { ask "Database password" ""; DB_PASS="$REPLY"; }
        [[ -n "$DB_NAME" ]]   || { ask "Database name" "$PROJECT"; DB_NAME="$REPLY"; }
        ;;
      direct)
        [[ -n "$PROJECT" ]] || { ask "Project name (e.g. myapp)" ""; PROJECT="$REPLY"; }
        ask "Database host" "$DB_HOST"; DB_HOST="$REPLY"
        ask "Port" "$DB_PORT"; DB_PORT="$REPLY"
        [[ -n "$DB_USER" ]] || { ask "Username" "postgres"; DB_USER="$REPLY"; }
        [[ -n "$DB_PASS" ]] || { ask "Password" ""; DB_PASS="$REPLY"; }
        [[ -n "$DB_NAME" ]] || { ask "Database name" "$PROJECT"; DB_NAME="$REPLY"; }
        ;;
    esac

    echo ""
    [[ -n "$BWLIMIT" ]]   || { ask "Upload rate limit" "${WALRUS_DEFAULT_BWLIMIT}"; BWLIMIT="$REPLY"; }
    [[ -n "$DAYS_KEEP" ]] || { ask "Retention days" "${WALRUS_DEFAULT_KEEP_DAYS}"; DAYS_KEEP="$REPLY"; }

    if [[ -z "$R2_BUCKET" ]]; then
      ask "Bucket" "$(r2_default_bucket)"
      R2_BUCKET="$REPLY"
    fi
    echo ""
  fi

  BWLIMIT="${BWLIMIT:-${WALRUS_DEFAULT_BWLIMIT}}"
  DAYS_KEEP="${DAYS_KEEP:-${WALRUS_DEFAULT_KEEP_DAYS}}"
  R2_BUCKET="${R2_BUCKET:-$(r2_default_bucket)}"

  [[ -n "$PROJECT" ]]  || die "Project name cannot be empty"
  [[ -n "$DB_USER" ]]  || die "Username cannot be empty"
  [[ -n "$DB_NAME" ]]  || die "Database name cannot be empty"
  validate_project_name "$PROJECT"

  if [[ "$MODE" == "docker" ]]; then
    [[ -n "$CONTAINER" ]] || die "Container name cannot be empty"
    validate_container_name "$CONTAINER"
  else
    [[ -n "$DB_HOST" ]] || die "Database host cannot be empty"
  fi

  # Check for duplicate project name
  if [[ -f "${WALRUS_CONF_DIR}/${PROJECT}.conf" ]]; then
    log_warn "Project '${PROJECT}' already exists"
    if $interactive; then
      if ! confirm "Overwrite existing config?"; then
        echo "  Cancelled"
        return
      fi
    else
      die "Project '${PROJECT}' already exists, use a different name or remove it first"
    fi
  fi

  local mode_label
  case "$MODE" in
    docker) mode_label="Docker: ${CONTAINER}" ;;
    direct) mode_label="${DB_HOST}:${DB_PORT}" ;;
  esac

  printf " ${C_BOLD}Initializing: %s${C_RESET}\n\n" "$PROJECT"
  log_dim "Mode: $mode_label"
  log_dim "Database: $DB_USER@$DB_NAME | Rate limit: $BWLIMIT | Retention: ${DAYS_KEEP} days"
  echo ""

  # ── Environment checks ──

  log_run "Checking environment..."
  pg_check_environment

  if ! pg_test_connection; then
    die "Database connection failed — please check your credentials"
  fi
  local pg_ver
  pg_ver=$(pg_get_version)
  log_ok "PostgreSQL ${pg_ver}"

  r2_ensure_bucket "$R2_BUCKET"
  log_ok "Bucket '${R2_BUCKET}'"
  echo ""

  # ── Directories ──

  mkdir -p "${WALRUS_LOCK_DIR}"
  mkdir -p "${WALRUS_DATA_DIR}/base/${PROJECT}"
  mkdir -p "${WALRUS_DATA_DIR}/wal/${PROJECT}"
  mkdir -p "${WALRUS_LOG_DIR}/${PROJECT}"

  # ── Save config ──

  save_project_conf "$PROJECT" "$MODE" "$DB_USER" "$DB_NAME" \
    "$BWLIMIT" "$DAYS_KEEP" "$R2_BUCKET" "$pg_ver"

  # ── WAL archiving ──

  log_run "Configuring WAL archiving..."

  local wal_archive_dir
  case "$MODE" in
    docker) wal_archive_dir="${WALRUS_CONTAINER_WAL_DIR}" ;;
    direct) wal_archive_dir="${WALRUS_DATA_DIR}/wal_archive/${PROJECT}" ;;
  esac

  local need_restart=false
  if pg_configure_wal_archive "$wal_archive_dir"; then
    need_restart=true
  fi

  # ── Systemd service ──

  _install_service "$PROJECT"

  # ── Restart if needed ──

  if $need_restart; then
    echo ""
    if $interactive; then
      local restart_msg
      case "$MODE" in
        docker) restart_msg="Need to restart container '${CONTAINER}' to enable WAL archiving. Restart now?" ;;
        direct) restart_msg="Need to restart PostgreSQL to enable WAL archiving. Restart now?" ;;
      esac
      if confirm "$restart_msg"; then
        _restart_and_verify
      else
        case "$MODE" in
          docker) log_warn "Please restart manually: docker restart ${CONTAINER}" ;;
          *)      log_warn "Please restart PostgreSQL manually" ;;
        esac
      fi
    else
      _restart_and_verify
    fi
    echo ""
  fi

  # ── Test ──

  log_run "Testing backup..."
  echo ""

  pg_switch_wal
  sleep 2

  if cmd_sync --project "$PROJECT"; then
    log_ok "WAL sync"
  else
    log_warn "WAL sync failed (can retry later)"
  fi

  if cmd_backup --project "$PROJECT"; then
    log_ok "Full backup + upload"
  else
    echo ""
    log_err "Backup test failed"
    log_dim "Please check the errors above. Common causes:"
    log_dim "  1. pg_hba.conf does not allow replication connections"
    log_dim "  2. User lacks REPLICATION privilege"
    log_dim "  3. max_wal_senders is set to 0"
    echo ""
    log_dim "After fixing, run: walrus backup --project ${PROJECT}"
    echo ""
    return
  fi

  local r2_count
  r2_count=$(rclone lsf "${WALRUS_R2_REMOTE}:${R2_BUCKET}/${PROJECT}/base/" 2>/dev/null | wc -l | xargs)
  if [[ "$r2_count" -gt 0 ]]; then
    log_ok "Remote verification passed (${r2_count} backup(s))"
  else
    log_warn "Remote upload verification failed, please check R2 connection"
  fi

  echo ""
  printf " ${C_GREEN}${C_BOLD}Done!${C_RESET} ${C_BOLD}%s${C_RESET} is now protected by walrus\n\n" "$PROJECT"
}

_init_usage() {
  cat <<'USAGE'
Usage: walrus init [options]

  Run without arguments for interactive setup.

Modes:
  --mode <docker|direct>   PostgreSQL deployment mode (default: docker)

Options:
  --project <name>         Project name
  --host <address>         Database host (default: localhost)
  --port <port>            Database port (default: 5432)
  --user <username>        Database username
  --password <password>    Database password
  --db <database>          Database name
  --bwlimit <rate>         Upload rate limit (default: 2M)
  --keep <days>            Retention days (default: 7)
  --bucket <name>          Bucket name (default: backup)

Docker mode:
  --container <name>       PostgreSQL Docker container name
USAGE
}

_restart_and_verify() {
  local restart_label
  case "$MODE" in
    docker) restart_label="container '${CONTAINER}'" ;;
    *)      restart_label="PostgreSQL" ;;
  esac

  log_run "Restarting ${restart_label}..."
  pg_restart

  if pg_verify_wal_archive; then
    log_ok "WAL archiving is active"
  else
    die "Failed to enable WAL archiving"
  fi
}
