#!/usr/bin/env bash
#
# walrus - PostgreSQL abstraction layer
# Unified interface: all modes connect via local psql/pg_basebackup
#
# All functions rely on project config vars being loaded:
#   MODE, DB_USER, DB_NAME, DB_PASS, DB_HOST, DB_PORT,
#   CONTAINER (docker mode only)

# ─── Find psql / pg_basebackup ───────────────────────────
# Scan common install paths if not in PATH

_pg_bin=""

_find_pg_bin() {
  [[ -n "$_pg_bin" ]] && return 0

  if command -v psql &>/dev/null; then
    _pg_bin="$(dirname "$(command -v psql)")"
    return 0
  fi

  local search_paths=(
    /Library/PostgreSQL/*/bin
    /opt/homebrew/opt/libpq/bin
    /opt/homebrew/opt/postgresql@*/bin
    /usr/local/opt/libpq/bin
    /usr/local/opt/postgresql@*/bin
    /usr/lib/postgresql/*/bin
    /usr/pgsql-*/bin
  )

  for pattern in "${search_paths[@]}"; do
    # shellcheck disable=SC2086
    for dir in $pattern; do
      if [[ -x "${dir}/psql" ]]; then
        _pg_bin="$dir"
        return 0
      fi
    done
  done

  return 1
}

_psql() {
  if [[ "$MODE" == "docker" ]]; then
    docker exec -e PGPASSWORD="${DB_PASS}" "$CONTAINER" \
      psql -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" "$@"
  else
    PGPASSWORD="${DB_PASS}" "${_pg_bin}/psql" \
      -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" \
      -U "$DB_USER" -d "$DB_NAME" "$@"
  fi
}

_pg_basebackup() {
  if [[ "$MODE" == "docker" ]]; then
    docker exec -e PGPASSWORD="${DB_PASS}" "$CONTAINER" \
      pg_basebackup -h localhost -p 5432 -U "$DB_USER" "$@"
  else
    PGPASSWORD="${DB_PASS}" "${_pg_bin}/pg_basebackup" \
      -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" \
      -U "$DB_USER" "$@"
  fi
}

# ─── Execute SQL ─────────────────────────────────────────

pg_exec_sql() {
  local sql="$1"
  _psql -t -c "$sql" 2>/dev/null | xargs
}

pg_exec_sql_quiet() {
  local sql="$1"
  _psql -c "$sql" &>/dev/null
}

# ─── Test database connection ────────────────────────────

pg_test_connection() {
  pg_exec_sql_quiet "SELECT 1;"
}

# ─── Get PG version ─────────────────────────────────────

pg_get_version() {
  pg_exec_sql "SHOW server_version;"
}

# ─── Run pg_basebackup ──────────────────────────────────

pg_run_basebackup() {
  local output_dir="$1"
  rm -rf "$output_dir" && mkdir -p "$output_dir"

  if [[ "$MODE" == "docker" ]]; then
    local container_tmp="/tmp/walrus_basebackup"
    docker exec "$CONTAINER" rm -rf "$container_tmp"
    docker exec "$CONTAINER" mkdir -p "$container_tmp"

    if ! _pg_basebackup -D "$container_tmp" -Ft -z \
      --checkpoint=spread \
      --max-rate="${WALRUS_DEFAULT_MAX_RATE}"; then
      docker exec "$CONTAINER" rm -rf "$container_tmp"
      return 1
    fi

    if ! docker cp "$CONTAINER:${container_tmp}/base.tar.gz" "${output_dir}/base.tar.gz"; then
      docker exec "$CONTAINER" rm -rf "$container_tmp"
      return 1
    fi
    docker exec "$CONTAINER" rm -rf "$container_tmp"
  else
    _pg_basebackup -D "$output_dir" -Ft -z \
      --checkpoint=spread \
      --max-rate="${WALRUS_DEFAULT_MAX_RATE}"
  fi
}

# ─── Configure WAL archiving ────────────────────────────

pg_configure_wal_archive() {
  local wal_dir="$1"

  local archive_mode
  archive_mode=$(pg_exec_sql "SHOW archive_mode;")

  if [[ "$archive_mode" == "on" ]]; then
    log_ok "WAL archiving already enabled"
    return 1
  fi

  if [[ "$MODE" == "docker" ]]; then
    docker exec "$CONTAINER" mkdir -p "$wal_dir"
  else
    mkdir -p "$wal_dir"
  fi

  pg_exec_sql_quiet "ALTER SYSTEM SET wal_level = 'replica';"
  pg_exec_sql_quiet "ALTER SYSTEM SET archive_mode = 'on';"
  pg_exec_sql_quiet "ALTER SYSTEM SET archive_command = 'cp %p ${wal_dir}/%f';"

  log_ok "WAL archiving configured"
  return 0
}

# ─── Restart PostgreSQL ──────────────────────────────────

pg_restart() {
  if [[ "$MODE" == "docker" ]]; then
    docker restart "$CONTAINER" >/dev/null 2>&1
  else
    local data_dir
    data_dir=$(pg_exec_sql "SHOW data_directory;")
    if command -v systemctl &>/dev/null && systemctl is-active postgresql &>/dev/null; then
      sudo systemctl restart postgresql
    elif command -v brew &>/dev/null && brew services list 2>/dev/null | grep -q "postgresql.*started"; then
      brew services restart postgresql
    elif [[ -n "$data_dir" ]] && [[ -x "${_pg_bin}/pg_ctl" ]]; then
      sudo -u postgres "${_pg_bin}/pg_ctl" restart -D "$data_dir" -m fast -w
    else
      die "Cannot restart PostgreSQL, please restart manually and re-run walrus init"
    fi
  fi
  sleep 2
}

# ─── Verify WAL archive is active ───────────────────────

pg_verify_wal_archive() {
  local check
  check=$(pg_exec_sql "SHOW archive_mode;")
  [[ "$check" == "on" ]]
}

# ─── Trigger WAL switch ─────────────────────────────────

pg_switch_wal() {
  pg_exec_sql_quiet "SELECT pg_switch_wal();" || true
}

# ─── Environment check ──────────────────────────────────

pg_check_environment() {
  if [[ "$MODE" == "docker" ]]; then
    require_cmd docker
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
      log_err "Container '${CONTAINER}' is not running"
      echo ""
      printf " ${C_DIM}Running containers:${C_RESET}\n"
      docker ps --format "   • {{.Names}} ({{.Image}})"
      exit 1
    fi
    log_ok "Container '${CONTAINER}'"

    if ! docker exec "$CONTAINER" which pg_basebackup &>/dev/null; then
      die "pg_basebackup not found in container '${CONTAINER}'"
    fi
    log_ok "PostgreSQL tools (in container)"
  else
    if ! _find_pg_bin; then
      die "PostgreSQL client tools (psql) not found, please install postgresql-client"
    fi
    log_ok "PostgreSQL client (${_pg_bin})"
  fi
}
