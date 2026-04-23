#!/usr/bin/env bash
#
# walrus - project management
# Load, resolve, list, and save project configurations

load_project_conf() {
  local project="$1"
  local conf="${WALRUS_CONF_DIR}/${project}.conf"
  [[ -f "$conf" ]] || die "Project '${project}' not registered, run 'walrus init' to add"
  # shellcheck disable=SC1090
  source "$conf"

  MODE="${MODE:-docker}"
  DB_HOST="${DB_HOST:-localhost}"
  DB_PORT="${DB_PORT:-5432}"
  DB_PASS="${DB_PASS:-}"

  # Migrate old mode names
  [[ "$MODE" == "ssh" ]] && MODE="direct"
  [[ "$MODE" == "local" ]] && MODE="direct"
  [[ "$MODE" == "remote" ]] && MODE="direct"
}

resolve_project() {
  local requested="${1:-}"

  if [[ -n "$requested" ]]; then
    load_project_conf "$requested"
    return
  fi

  local projects=()
  if [[ -d "$WALRUS_CONF_DIR" ]]; then
    for f in "${WALRUS_CONF_DIR}"/*.conf; do
      [[ -f "$f" ]] || continue
      projects+=("$(basename "$f" .conf)")
    done
  fi

  case ${#projects[@]} in
    0) die "No projects registered, run 'walrus init' to add one" ;;
    1)
      load_project_conf "${projects[0]}"
      ;;
    *)
      log_err "Multiple projects found, please specify --project:"
      for p in "${projects[@]}"; do
        log_dim "  $p"
      done
      exit 1
      ;;
  esac
}

list_all_projects() {
  [[ -d "$WALRUS_CONF_DIR" ]] || return
  for f in "${WALRUS_CONF_DIR}"/*.conf; do
    [[ -f "$f" ]] || continue
    basename "$f" .conf
  done
}

save_project_conf() {
  local project="$1" mode="$2" db_user="$3" db_name="$4"
  local bwlimit="$5" days_keep="$6" r2_bucket="$7"

  mkdir -p "${WALRUS_CONF_DIR}"
  cat > "${WALRUS_CONF_DIR}/${project}.conf" <<CONF
# walrus project config — ${project}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
PROJECT="${project}"
MODE="${mode}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${db_user}"
DB_NAME="${db_name}"
DB_PASS="${DB_PASS}"
BWLIMIT="${bwlimit}"
DAYS_KEEP=${days_keep}
R2_REMOTE="${WALRUS_R2_REMOTE}"
R2_BUCKET="${r2_bucket}"
CONF

  if [[ "$mode" == "docker" ]]; then
    cat >> "${WALRUS_CONF_DIR}/${project}.conf" <<CONF
CONTAINER="${CONTAINER}"
CONF
  fi
}
