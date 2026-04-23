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

  # ── Cleanup (always keep at least 1 backup) ──
  _blog "Cleaning up backups older than ${DAYS_KEEP} days..."

  # Local: delete old backups but keep the latest one
  local local_backups
  local_backups=$(ls -t "$local_dir"/base_*.tar.gz 2>/dev/null || true)
  if [[ -n "$local_backups" ]]; then
    echo "$local_backups" | tail -n +2 | while read -r f; do
      if [[ -n "$f" ]] && find "$f" -mtime +"$DAYS_KEEP" -print -quit 2>/dev/null | grep -q .; then
        rm -f "$f"
      fi
    done
  fi
  find "$wal_dir" -type f -mtime +"$DAYS_KEEP" -delete 2>/dev/null || true

  # R2: delete old backups but keep at least 1
  local cutoff
  cutoff=$(date -d "-${DAYS_KEEP} days" +%Y%m%d 2>/dev/null || date -v-"${DAYS_KEEP}"d +%Y%m%d)
  local r2_files
  r2_files=$(rclone lsf "${r2_path}/base/" 2>/dev/null | sort || true)
  local r2_total
  r2_total=$(echo "$r2_files" | grep -c . 2>/dev/null || echo 0)

  if [[ "$r2_total" -gt 1 ]]; then
    echo "$r2_files" | head -n $((r2_total - 1)) | while read -r file; do
      local fdate
      fdate=$(echo "$file" | grep -Eo '[0-9]{8}' | head -1 || true)
      if [[ -n "$fdate" ]] && [[ "$fdate" -lt "$cutoff" ]] 2>/dev/null; then
        _blog "Deleting: $file"
        rclone deletefile "${r2_path}/base/${file}"
      fi
    done
  fi

  rclone delete "${r2_path}/wal/" --min-age "${DAYS_KEEP}d" 2>/dev/null || true

  _blog "Done"
}
