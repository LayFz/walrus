#!/usr/bin/env bash
#
# walrus logs - view project logs

cmd_logs() {
  local project_arg="" follow=false lines=30

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project_arg="$2"; shift 2;;
      -f|--follow) follow=true; shift;;
      -n) lines="$2"; shift 2;;
      -h|--help) echo "Usage: walrus logs [--project <name>] [-f] [-n lines]"; return;;
      *) shift;;
    esac
  done

  resolve_project "$project_arg"

  local backup_log="${WALRUS_LOG_DIR}/${PROJECT}/backup.log"
  local sync_log="${WALRUS_LOG_DIR}/${PROJECT}/sync.log"

  if $follow; then
    [[ -f "$backup_log" ]] || die "Log file does not exist"
    tail -f "$backup_log"
    return
  fi

  if [[ -f "$backup_log" ]]; then
    printf "\n ${C_BOLD}Backup Log${C_RESET} ${C_DIM}(last %s lines)${C_RESET}\n\n" "$lines"
    tail -"$lines" "$backup_log"
    echo ""
  fi

  if [[ -f "$sync_log" ]]; then
    printf " ${C_BOLD}Sync Log${C_RESET} ${C_DIM}(last 10 lines)${C_RESET}\n\n"
    tail -10 "$sync_log"
    echo ""
  fi

  if [[ ! -f "$backup_log" ]] && [[ ! -f "$sync_log" ]]; then
    log_warn "No logs found"
  fi
}
