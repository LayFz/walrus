#!/usr/bin/env bash
#
# walrus backup - perform a full physical backup

cmd_backup() {
  local project_arg=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -h|--help) echo "用法: walrus backup [--project <名称>]"; return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"
  acquire_lock "$PROJECT"

  local date_tag logfile local_dir wal_dir r2_path
  date_tag=$(date +%Y%m%d_%H%M%S)
  logfile="${WALRUS_LOG_DIR}/${PROJECT}/backup.log"
  local_dir="${WALRUS_DATA_DIR}/base/${PROJECT}"
  wal_dir="${WALRUS_DATA_DIR}/wal/${PROJECT}"
  r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}"

  mkdir -p "$local_dir" "$(dirname "$logfile")"

  _blog() { ts_log "$PROJECT" "$1" "$logfile"; }

  # ── Base backup ──
  _blog "开始 base backup..."
  docker exec "$CONTAINER" sh -c "rm -rf ${WALRUS_CONTAINER_TMP_DIR} && mkdir -p ${WALRUS_CONTAINER_TMP_DIR}"
  docker exec "$CONTAINER" pg_basebackup \
    -U "$DB_USER" -D "${WALRUS_CONTAINER_TMP_DIR}" -Ft -z \
    --checkpoint=spread \
    --max-rate="${WALRUS_DEFAULT_MAX_RATE}"

  docker cp "$CONTAINER:${WALRUS_CONTAINER_TMP_DIR}/base.tar.gz" "${local_dir}/base_${date_tag}.tar.gz"
  docker exec "$CONTAINER" rm -rf "${WALRUS_CONTAINER_TMP_DIR}"

  local size
  size=$(du -sh "${local_dir}/base_${date_tag}.tar.gz" | cut -f1)
  _blog "base backup 完成 (${size})"

  # ── Upload ──
  _blog "上传 R2 (限速 ${BWLIMIT})..."
  rclone copy "${local_dir}/base_${date_tag}.tar.gz" "${r2_path}/base/" \
    --bwlimit "$BWLIMIT" --checksum
  _blog "上传完成"

  # ── Sync WAL ──
  if [[ -d "$wal_dir" ]] && [[ -n "$(ls -A "$wal_dir" 2>/dev/null)" ]]; then
    _blog "同步 WAL..."
    rclone copy "${wal_dir}/" "${r2_path}/wal/" --bwlimit "$BWLIMIT" --checksum
    _blog "WAL 已同步"
  fi

  # ── Cleanup ──
  _blog "清理 ${DAYS_KEEP} 天前的备份..."

  find "$local_dir" -name "base_*.tar.gz" -mtime +"$DAYS_KEEP" -delete 2>/dev/null || true
  find "$wal_dir" -type f -mtime +"$DAYS_KEEP" -delete 2>/dev/null || true

  local cutoff
  cutoff=$(date -d "-${DAYS_KEEP} days" +%Y%m%d 2>/dev/null || date -v-"${DAYS_KEEP}"d +%Y%m%d)
  rclone lsf "${r2_path}/base/" 2>/dev/null | while read -r file; do
    local fdate
    fdate=$(echo "$file" | grep -oP '\d{8}' | head -1 || true)
    if [[ -n "$fdate" ]] && [[ "$fdate" -lt "$cutoff" ]] 2>/dev/null; then
      _blog "删除: $file"
      rclone deletefile "${r2_path}/base/${file}"
    fi
  done

  rclone delete "${r2_path}/wal/" --min-age "${DAYS_KEEP}d" 2>/dev/null || true

  _blog "完成 ✓"
}
