#!/usr/bin/env bash
#
# walrus help - display usage information

cmd_help() {
  banner
  cat <<HELP
  ${C_BOLD}用法${C_RESET}
    walrus <command> [options]

  ${C_BOLD}入门${C_RESET}
    ${C_CYAN}config${C_RESET}    配置 R2 存储连接         ${C_DIM}walrus config${C_RESET}
    ${C_CYAN}init${C_RESET}      注册项目 (交互式引导)    ${C_DIM}walrus init${C_RESET}

  ${C_BOLD}备份${C_RESET}
    ${C_CYAN}backup${C_RESET}    执行全量备份             ${C_DIM}walrus backup${C_RESET}
    ${C_CYAN}sync${C_RESET}      同步 WAL 日志            ${C_DIM}walrus sync${C_RESET}

  ${C_BOLD}恢复${C_RESET}
    ${C_CYAN}restore${C_RESET}   从 R2 恢复数据库         ${C_DIM}walrus restore${C_RESET}

  ${C_BOLD}管理${C_RESET}
    ${C_CYAN}status${C_RESET}    查看项目状态             ${C_DIM}walrus status${C_RESET}
    ${C_CYAN}list${C_RESET}      查看 R2 备份详情         ${C_DIM}walrus list${C_RESET}
    ${C_CYAN}logs${C_RESET}      查看日志                 ${C_DIM}walrus logs [-f]${C_RESET}
    ${C_CYAN}service${C_RESET}   管理系统服务             ${C_DIM}walrus service status${C_RESET}
    ${C_CYAN}remove${C_RESET}    移除项目                 ${C_DIM}walrus remove --project x${C_RESET}

  ${C_BOLD}快速开始${C_RESET}
    1. walrus config              ${C_DIM}# 配置 R2${C_RESET}
    2. walrus init                ${C_DIM}# 注册项目${C_RESET}
    3. walrus status              ${C_DIM}# 确认一切正常${C_RESET}

  ${C_BOLD}提示${C_RESET}
    • 只有一个项目时 --project 可省略
    • 命令缩写: st=status, ls=list, rm=remove
    • 每个命令支持 -h 查看帮助

HELP
}
