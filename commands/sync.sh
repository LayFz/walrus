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

  # Copy WAL from PG host to local walrus data dir
  if [[ "$MODE" == "docker" ]]; then
    local wal_archive_dir="${WALRUS_CONTAINER_WAL_DIR}"
    docker cp "$CONTAINER:${wal_archive_dir}/." "$wal_dir/" 2>/dev/null || true
    docker exec "$CONTAINER" sh -c "rm -f ${wal_archive_dir}/*" 2>/dev/null || true
  else
    local wal_archive_dir="${WALRUS_DATA_DIR}/wal_archive/${PROJECT}"
    mkdir -p "$wal_archive_dir"
    cp -f "${wal_archive_dir}"/* "$wal_dir/" 2>/dev/null || true
    rm -f "${wal_archive_dir}"/* 2>/dev/null || true
  fi

  # Upload new WAL files
  if [[ -n "$(ls -A "$wal_dir" 2>/dev/null)" ]]; then
    rclone copy "${wal_dir}/" "${r2_path}/" --bwlimit "$BWLIMIT" --checksum --quiet
  fi
}
