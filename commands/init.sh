#!/usr/bin/env bash
#
# walrus init - register a project and configure automatic backups

cmd_init() {
  local PROJECT="" CONTAINER="" DB_USER="" DB_NAME=""
  local BWLIMIT="" DAYS_KEEP="" R2_BUCKET=""
  local _r2_ak="" _r2_sk="" _r2_ep=""
  local interactive=true

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)       PROJECT="$2"; interactive=false; shift 2;;
      --container)     CONTAINER="$2"; shift 2;;
      --user)          DB_USER="$2"; shift 2;;
      --db)            DB_NAME="$2"; shift 2;;
      --r2-access-key) _r2_ak="$2"; shift 2;;
      --r2-secret-key) _r2_sk="$2"; shift 2;;
      --r2-endpoint)   _r2_ep="$2"; shift 2;;
      --bwlimit)       BWLIMIT="$2"; shift 2;;
      --keep)          DAYS_KEEP="$2"; shift 2;;
      --bucket)        R2_BUCKET="$2"; shift 2;;
      -h|--help)       _init_usage; return;;
      *) die "未知参数: $1";;
    esac
  done

  banner
  require_root "init"

  # ── R2 setup ──

  if [[ -n "$_r2_ak" ]] && [[ -n "$_r2_sk" ]] && [[ -n "$_r2_ep" ]]; then
    log_run "配置 R2..."
    ensure_rclone
    r2_configure "$_r2_ak" "$_r2_sk" "$_r2_ep"
    log_ok "R2 配置完成"
  fi

  if ! r2_is_configured; then
    echo ""
    log_warn "R2 尚未配置"
    echo ""
    if $interactive && confirm "现在配置 R2?"; then
      cmd_config
    else
      die "请先运行 'walrus config' 配置 R2 存储"
    fi
  fi

  r2_check_connection || die "R2 连接失败，运行 'walrus config' 重新配置"

  # ── Interactive prompts ──

  if $interactive || [[ -z "$PROJECT" ]]; then
    printf " ${C_BOLD}注册新项目${C_RESET}\n\n"

    # Show running PG containers
    local pg_containers
    pg_containers=$(docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i "postgres" || true)
    if [[ -n "$pg_containers" ]]; then
      printf " ${C_DIM}检测到 PostgreSQL 容器:${C_RESET}\n"
      while IFS=$'\t' read -r name image; do
        printf "   ${C_CYAN}•${C_RESET} %s ${C_DIM}(%s)${C_RESET}\n" "$name" "$image"
      done <<< "$pg_containers"
      echo ""
    fi

    [[ -n "$PROJECT" ]]   || { ask "项目名称 (如 myapp)" ""; PROJECT="$REPLY"; }
    [[ -n "$CONTAINER" ]] || { ask "PostgreSQL 容器名" ""; CONTAINER="$REPLY"; }
    [[ -n "$DB_USER" ]]   || { ask "数据库用户名" ""; DB_USER="$REPLY"; }
    [[ -n "$DB_NAME" ]]   || { ask "数据库名" "$PROJECT"; DB_NAME="$REPLY"; }
    [[ -n "$BWLIMIT" ]]   || { ask "上传限速" "${WALRUS_DEFAULT_BWLIMIT}"; BWLIMIT="$REPLY"; }
    [[ -n "$DAYS_KEEP" ]] || { ask "备份保留天数" "${WALRUS_DEFAULT_KEEP_DAYS}"; DAYS_KEEP="$REPLY"; }

    if [[ -z "$R2_BUCKET" ]]; then
      ask "R2 Bucket" "$(r2_default_bucket)"
      R2_BUCKET="$REPLY"
    fi
    echo ""
  fi

  # Defaults
  BWLIMIT="${BWLIMIT:-${WALRUS_DEFAULT_BWLIMIT}}"
  DAYS_KEEP="${DAYS_KEEP:-${WALRUS_DEFAULT_KEEP_DAYS}}"
  R2_BUCKET="${R2_BUCKET:-$(r2_default_bucket)}"

  # Validate
  [[ -n "$PROJECT" ]]   || die "项目名称不能为空"
  [[ -n "$CONTAINER" ]] || die "容器名不能为空"
  [[ -n "$DB_USER" ]]   || die "用户名不能为空"
  [[ -n "$DB_NAME" ]]   || die "数据库名不能为空"
  validate_project_name "$PROJECT"

  printf " ${C_BOLD}初始化: %s${C_RESET}\n\n" "$PROJECT"
  log_dim "容器: $CONTAINER | 数据库: $DB_USER@$DB_NAME"
  log_dim "限速: $BWLIMIT | 保留: ${DAYS_KEEP}天 | Bucket: $R2_BUCKET"
  echo ""

  # ── Environment checks ──

  log_run "检测环境..."

  require_cmd docker

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    log_err "容器 '${CONTAINER}' 未运行"
    echo ""
    printf " ${C_DIM}当前运行的容器:${C_RESET}\n"
    docker ps --format "   • {{.Names}} ({{.Image}})"
    exit 1
  fi
  log_ok "容器 '${CONTAINER}'"

  if ! docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    die "数据库连接失败 — 请检查用户名和数据库名"
  fi
  local pg_ver
  pg_ver=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW server_version;" | xargs)
  log_ok "PostgreSQL ${pg_ver}"

  r2_ensure_bucket "$R2_BUCKET"
  log_ok "R2 Bucket '${R2_BUCKET}'"
  echo ""

  # ── Directories ──

  mkdir -p "${WALRUS_LOCK_DIR}"
  mkdir -p "${WALRUS_DATA_DIR}/base/${PROJECT}"
  mkdir -p "${WALRUS_DATA_DIR}/wal/${PROJECT}"
  mkdir -p "${WALRUS_LOG_DIR}/${PROJECT}"

  # ── Save config ──

  save_project_conf "$PROJECT" "$CONTAINER" "$DB_USER" "$DB_NAME" \
    "$BWLIMIT" "$DAYS_KEEP" "$R2_BUCKET"

  # ── WAL archiving ──

  log_run "配置 WAL 归档..."

  local need_restart=false
  local archive_mode
  archive_mode=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW archive_mode;" | xargs)

  if [[ "$archive_mode" == "on" ]]; then
    log_ok "WAL 归档已开启"
  else
    docker exec "$CONTAINER" mkdir -p "${WALRUS_CONTAINER_WAL_DIR}"
    docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
      -c "ALTER SYSTEM SET wal_level = 'replica';" >/dev/null
    docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
      -c "ALTER SYSTEM SET archive_mode = 'on';" >/dev/null
    docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
      -c "ALTER SYSTEM SET archive_command = 'cp %p ${WALRUS_CONTAINER_WAL_DIR}/%f';" >/dev/null
    need_restart=true
    log_ok "WAL 归档已配置"
  fi

  # ── Systemd service ──

  _install_service "$PROJECT"

  # ── Install self ──

  local self_path
  self_path="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/walrus"
  if [[ -f "$self_path" ]] && [[ "$self_path" != "/usr/local/bin/walrus" ]]; then
    cp "$self_path" /usr/local/bin/walrus
    chmod +x /usr/local/bin/walrus
  fi

  # ── Restart container ──

  if $need_restart; then
    echo ""
    if $interactive; then
      if confirm "需要重启容器 '${CONTAINER}' 以启用 WAL 归档，现在重启?"; then
        _restart_and_verify "$CONTAINER" "$DB_USER" "$DB_NAME"
      else
        log_warn "请稍后手动重启: docker restart ${CONTAINER}"
      fi
    else
      _restart_and_verify "$CONTAINER" "$DB_USER" "$DB_NAME"
    fi
    echo ""
  fi

  # ── Test ──

  log_run "测试备份..."
  echo ""

  docker exec "$CONTAINER" mkdir -p "${WALRUS_CONTAINER_WAL_DIR}" 2>/dev/null || true
  docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT pg_switch_wal();" &>/dev/null || true
  sleep 2

  cmd_sync --project "$PROJECT" 2>/dev/null
  log_ok "WAL 同步"

  cmd_backup --project "$PROJECT" 2>/dev/null
  log_ok "全量备份 + R2 上传"

  local r2_count
  r2_count=$(rclone lsf "${WALRUS_R2_REMOTE}:${R2_BUCKET}/${PROJECT}/base/" 2>/dev/null | wc -l | xargs)
  if [[ "$r2_count" -gt 0 ]]; then
    log_ok "R2 验证通过 (${r2_count} 个备份)"
  else
    die "R2 上传验证失败"
  fi

  echo ""
  printf " ${C_GREEN}${C_BOLD}搞定!${C_RESET} ${C_BOLD}%s${C_RESET} 已在 walrus 的保护下 🦭\n\n" "$PROJECT"
}

_init_usage() {
  cat <<'USAGE'
用法: walrus init [选项]

  不带参数运行将进入交互式引导。

选项:
  --project <名称>         项目名称
  --container <容器名>     PostgreSQL Docker 容器名
  --user <用户名>          数据库用户名
  --db <数据库名>          数据库名
  --r2-access-key <key>    R2 Access Key (首次配置)
  --r2-secret-key <key>    R2 Secret Key (首次配置)
  --r2-endpoint <url>      R2 Endpoint (首次配置)
  --bwlimit <速率>         上传限速 (默认: 2M)
  --keep <天数>            保留天数 (默认: 7)
  --bucket <名称>          R2 Bucket (默认: backup)
USAGE
}

_restart_and_verify() {
  local container="$1" user="$2" db="$3"
  log_run "重启容器 '${container}'..."
  docker restart "$container" >/dev/null 2>&1
  sleep 3

  local check
  check=$(docker exec "$container" psql -U "$user" -d "$db" -t -c "SHOW archive_mode;" | xargs)
  if [[ "$check" == "on" ]]; then
    log_ok "WAL 归档已生效"
  else
    die "WAL 归档启用失败，请检查: docker logs ${container}"
  fi
}
