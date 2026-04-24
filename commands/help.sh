#!/usr/bin/env bash
#
# walrus help - display usage information

cmd_help() {
  banner
  cat <<HELP
  ${C_BOLD}Usage${C_RESET}
    walrus <command> [options]

  ${C_BOLD}Getting Started${C_RESET}
    ${C_CYAN}config${C_RESET}    Configure remote storage (R2/S3/...)  ${C_DIM}walrus config${C_RESET}
    ${C_CYAN}init${C_RESET}      Register a project (interactive)      ${C_DIM}walrus init${C_RESET}

  ${C_BOLD}Deployment Modes${C_RESET}
    ${C_DIM}walrus init supports two PostgreSQL deployment modes:${C_RESET}
    ${C_CYAN}docker${C_RESET}    PostgreSQL running in a Docker container
    ${C_CYAN}direct${C_RESET}    Connect via host:port (local or remote)

  ${C_BOLD}Backup${C_RESET}
    ${C_CYAN}backup${C_RESET}    Run a full backup                     ${C_DIM}walrus backup${C_RESET}
    ${C_CYAN}sync${C_RESET}      Sync WAL logs                         ${C_DIM}walrus sync${C_RESET}

  ${C_BOLD}Restore${C_RESET}
    ${C_CYAN}restore${C_RESET}   Restore database from R2              ${C_DIM}walrus restore${C_RESET}

  ${C_BOLD}Management${C_RESET}
    ${C_CYAN}status${C_RESET}    Show project status                   ${C_DIM}walrus status${C_RESET}
    ${C_CYAN}list${C_RESET}      Show R2 backup details                ${C_DIM}walrus list${C_RESET}
    ${C_CYAN}logs${C_RESET}      View logs                             ${C_DIM}walrus logs [-f]${C_RESET}
    ${C_CYAN}service${C_RESET}   Manage system services                ${C_DIM}walrus service status${C_RESET}
    ${C_CYAN}remove${C_RESET}    Remove a project                      ${C_DIM}walrus remove --project x${C_RESET}
    ${C_CYAN}update${C_RESET}    Update walrus to latest version       ${C_DIM}walrus update${C_RESET}

  ${C_BOLD}Quick Start${C_RESET}
    1. walrus config              ${C_DIM}# Configure R2${C_RESET}
    2. walrus init                ${C_DIM}# Register project (choose mode)${C_RESET}
    3. walrus status              ${C_DIM}# Verify everything is working${C_RESET}

  ${C_BOLD}Tips${C_RESET}
    * --project can be omitted when only one project is registered
    * Aliases: st=status, ls=list, rm=remove
    * Each command supports -h for help

HELP
}
