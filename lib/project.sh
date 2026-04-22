#!/usr/bin/env bash
#
# walrus - project management
# Load, resolve, list, and save project configurations

# Load a specific project config by name
load_project_conf() {
  local project="$1"
  local conf="${WALRUS_CONF_DIR}/${project}.conf"
  [[ -f "$conf" ]] || die "项目 '${project}' 未注册，运行 'walrus init' 添加"
  # shellcheck disable=SC1090
  source "$conf"
}

# Resolve project: use given name, or auto-detect if only one registered
# After calling, all project vars (PROJECT, CONTAINER, etc.) are set
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
    0) die "暂无已注册项目，运行 'walrus init' 添加" ;;
    1)
      # shellcheck disable=SC1090
      source "${WALRUS_CONF_DIR}/${projects[0]}.conf"
      ;;
    *)
      log_err "有多个项目，请指定 --project:"
      for p in "${projects[@]}"; do
        log_dim "  $p"
      done
      exit 1
      ;;
  esac
}

# List all registered project names (one per line)
list_all_projects() {
  [[ -d "$WALRUS_CONF_DIR" ]] || return
  for f in "${WALRUS_CONF_DIR}"/*.conf; do
    [[ -f "$f" ]] || continue
    basename "$f" .conf
  done
}

# Save project configuration
save_project_conf() {
  local project="$1" container="$2" db_user="$3" db_name="$4"
  local bwlimit="$5" days_keep="$6" r2_bucket="$7"

  mkdir -p "${WALRUS_CONF_DIR}"
  cat > "${WALRUS_CONF_DIR}/${project}.conf" <<CONF
# walrus project config — ${project}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
PROJECT="${project}"
CONTAINER="${container}"
DB_USER="${db_user}"
DB_NAME="${db_name}"
BWLIMIT="${bwlimit}"
DAYS_KEEP=${days_keep}
R2_REMOTE="${WALRUS_R2_REMOTE}"
R2_BUCKET="${r2_bucket}"
CONF
}
