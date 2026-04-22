#!/usr/bin/env bash
#
# walrus sync - sync WAL logs to R2

cmd_sync() {
  local project_arg=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -h|--help) echo "用法: walrus sync [--project <名称>]"; return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  local wal_dir="${WALRUS_DATA_DIR}/wal/${PROJECT}"
  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}/wal"

  mkdir -p "$wal_dir"

  # Copy WAL from container to host
  docker exec "$CONTAINER" mkdir -p "${WALRUS_CONTAINER_WAL_DIR}" 2>/dev/null || true
  docker cp "$CONTAINER:${WALRUS_CONTAINER_WAL_DIR}/." "$wal_dir/" 2>/dev/null || true
  docker exec "$CONTAINER" sh -c "rm -f ${WALRUS_CONTAINER_WAL_DIR}/*" 2>/dev/null || true

  # Upload only new WAL files
  if [[ -n "$(ls -A "$wal_dir" 2>/dev/null)" ]]; then
    rclone copy "${wal_dir}/" "${r2_path}/" --bwlimit "$BWLIMIT" --checksum --quiet
  fi
}
