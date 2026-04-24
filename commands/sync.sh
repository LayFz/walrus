#!/usr/bin/env bash
#
# walrus sync - sync WAL logs to R2

cmd_sync() {
  local project_arg=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -h|--help) echo "Usage: walrus sync [--project <name>]"; return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  local wal_dir="${WALRUS_DATA_DIR}/wal/${PROJECT}"
  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}/wal"

  mkdir -p "$wal_dir"

  # Copy WAL from PG host to local staging dir
  local copy_ok=false
  if [[ "$MODE" == "docker" ]]; then
    local wal_archive_dir="${WALRUS_CONTAINER_WAL_DIR}"
    if docker cp "$CONTAINER:${wal_archive_dir}/." "$wal_dir/" 2>/dev/null; then
      copy_ok=true
    fi
  else
    local wal_archive_dir="${WALRUS_DATA_DIR}/wal_archive/${PROJECT}"
    mkdir -p "$wal_archive_dir"
    if cp -f "${wal_archive_dir}"/* "$wal_dir/" 2>/dev/null; then
      copy_ok=true
    fi
  fi

  # Upload new WAL files, only delete source after successful upload
  if [[ -n "$(ls -A "$wal_dir" 2>/dev/null)" ]]; then
    if rclone copy "${wal_dir}/" "${r2_path}/" --bwlimit "$BWLIMIT" --checksum --quiet; then
      # Upload succeeded and copy succeeded, safe to clean up source WAL
      if $copy_ok; then
        if [[ "$MODE" == "docker" ]]; then
          docker exec "$CONTAINER" sh -c "rm -f ${wal_archive_dir}/*" 2>/dev/null || true
        else
          rm -f "${wal_archive_dir}"/* 2>/dev/null || true
        fi
      fi
    fi
  fi
}
