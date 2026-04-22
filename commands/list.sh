#!/usr/bin/env bash
#
# walrus list - list backups on R2

cmd_list() {
  local project_arg=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -h|--help) echo "用法: walrus list [--project <名称>]"; return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  local r2_path="${R2_REMOTE}:${R2_BUCKET}/${PROJECT}"

  printf "\n ${C_BOLD}R2 备份: %s${C_RESET}\n\n" "$PROJECT"

  # Base backups
  printf " ${C_CYAN}Base Backups${C_RESET}\n"
  local bases
  bases=$(rclone lsf "${r2_path}/base/" --format "sp" 2>/dev/null | sort || true)
  if [[ -z "$bases" ]]; then
    log_dim "  (空)"
  else
    while read -r line; do
      local size name
      size=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      local hr_size
      hr_size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")
      local fdate
      fdate=$(echo "$name" | sed 's/base_\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*/\1-\2-\3 \4:\5:\6/')
      printf "   %s  ${C_DIM}%s${C_RESET}  %s\n" "$fdate" "$hr_size" "$name"
    done <<< "$bases"
  fi

  echo ""

  # WAL count
  local wal_count
  wal_count=$(rclone lsf "${r2_path}/wal/" 2>/dev/null | wc -l | xargs)
  printf " ${C_CYAN}WAL Segments${C_RESET}  %s 个\n\n" "$wal_count"
}
