#!/usr/bin/env bash
#
# walrus backup - perform a full physical backup

cmd_backup() {
  local project_arg=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -h|--help) echo "Usage: walrus backup [--project <name>]"; return;;
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

  # ── Base backup (output to local temp dir) ──
  local tmp_dir="/tmp/walrus_backup_${PROJECT}"

  _blog "Starting base backup..."
  pg_run_basebackup "$tmp_dir"

  mv "${tmp_dir}/base.tar.gz" "${local_dir}/base_${date_tag}.tar.gz"
  rm -rf "$tmp_dir"

  local size
  size=$(du -sh "${local_dir}/base_${date_tag}.tar.gz" | cut -f1)
  _blog "Base backup complete (${size})"

  # ── Upload ──
  _blog "Uploading to R2 (rate limit: ${BWLIMIT})..."
  if ! rclone copy "${local_dir}/base_${date_tag}.tar.gz" "${r2_path}/base/" \
    --bwlimit "$BWLIMIT" --checksum; then
    _blog "Upload failed!"
    die "Failed to upload backup to R2"
  fi
  _blog "Upload complete"

  # ── Sync WAL ──
  if [[ -d "$wal_dir" ]] && [[ -n "$(ls -A "$wal_dir" 2>/dev/null)" ]]; then
    _blog "Syncing WAL..."
    rclone copy "${wal_dir}/" "${r2_path}/wal/" --bwlimit "$BWLIMIT" --checksum
    _blog "WAL synced"
  fi

  # ── Cleanup ──
  _blog "Cleaning up backups older than ${DAYS_KEEP} days..."

  find "$local_dir" -name "base_*.tar.gz" -mtime +"$DAYS_KEEP" -delete 2>/dev/null || true
  find "$wal_dir" -type f -mtime +"$DAYS_KEEP" -delete 2>/dev/null || true

  local cutoff
  cutoff=$(date -d "-${DAYS_KEEP} days" +%Y%m%d 2>/dev/null || date -v-"${DAYS_KEEP}"d +%Y%m%d)
  rclone lsf "${r2_path}/base/" 2>/dev/null | while read -r file; do
    local fdate
    fdate=$(echo "$file" | grep -Eo '[0-9]{8}' | head -1 || true)
    if [[ -n "$fdate" ]] && [[ "$fdate" -lt "$cutoff" ]] 2>/dev/null; then
      _blog "Deleting: $file"
      rclone deletefile "${r2_path}/base/${file}"
    fi
  done

  rclone delete "${r2_path}/wal/" --min-age "${DAYS_KEEP}d" 2>/dev/null || true

  _blog "Done"
}
