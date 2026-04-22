#!/usr/bin/env bash
#
# walrus installer
# curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
#

set -euo pipefail

readonly REPO="LayFz/walrus"
readonly BRANCH="main"
readonly INSTALL_BIN="/usr/local/bin/walrus"
readonly INSTALL_DIR="/opt/walrus"
readonly RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# Colors
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m' C_GREEN=$'\033[0;32m' C_CYAN=$'\033[0;36m'
  C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RESET=$'\033[0m'
else
  C_RED="" C_GREEN="" C_CYAN="" C_BOLD="" C_DIM="" C_RESET=""
fi

_ok()  { printf " ${C_GREEN}✓${C_RESET} %s\n" "$1"; }
_run() { printf " ${C_CYAN}→${C_RESET} %s\n" "$1"; }
_err() { printf " ${C_RED}✗${C_RESET} %s\n" "$1" >&2; }

printf "%s" "${C_BOLD}"
cat <<'BANNER'

  ██╗    ██╗ █████╗ ██╗     ██████╗ ██╗   ██╗███████╗
  ██║    ██║██╔══██╗██║     ██╔══██╗██║   ██║██╔════╝
  ██║ █╗ ██║███████║██║     ██████╔╝██║   ██║███████╗
  ██║███╗██║██╔══██║██║     ██╔══██╗██║   ██║╚════██║
  ╚███╔███╔╝██║  ██║███████╗██║  ██║╚██████╔╝███████║
   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
BANNER
printf "%s\n" "${C_RESET}"
printf "  ${C_DIM}PostgreSQL backup buddy for indie hackers${C_RESET}\n\n"

# ── Root check ──

if [[ "$(id -u)" -ne 0 ]]; then
  _err "需要 root 权限"
  printf "\n   ${C_DIM}curl -sSL %s/install.sh | sudo bash${C_RESET}\n\n" "$RAW_BASE"
  exit 1
fi

# ── Download helper ──

download() {
  local url="$1" dest="$2"
  if command -v curl &>/dev/null; then
    local code
    code=$(curl -sSL -w "%{http_code}" "$url" -o "$dest")
    if [[ "$code" != "200" ]]; then
      rm -f "$dest"
      return 1
    fi
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url" || return 1
  else
    _err "需要 curl 或 wget"
    exit 1
  fi
}

# ── Create directory structure ──

_run "创建目录结构..."

mkdir -p "${INSTALL_DIR}"/{conf,data,logs,locks,lib,commands}

# ── Download all files ──

_run "下载 walrus..."

# File list: path relative to repo root
FILES=(
  "walrus"
  "lib/constants.sh"
  "lib/colors.sh"
  "lib/logger.sh"
  "lib/cleanup.sh"
  "lib/utils.sh"
  "lib/lock.sh"
  "lib/project.sh"
  "lib/r2.sh"
  "commands/config.sh"
  "commands/init.sh"
  "commands/backup.sh"
  "commands/sync.sh"
  "commands/restore.sh"
  "commands/status.sh"
  "commands/list.sh"
  "commands/logs.sh"
  "commands/remove.sh"
  "commands/service.sh"
  "commands/help.sh"
)

fail_count=0
for f in "${FILES[@]}"; do
  dest="${INSTALL_DIR}/${f}"
  mkdir -p "$(dirname "$dest")"
  if download "${RAW_BASE}/${f}" "$dest"; then
    chmod +x "$dest" 2>/dev/null || true
  else
    _err "下载失败: $f"
    fail_count=$((fail_count + 1))
  fi
done

if [[ $fail_count -gt 0 ]]; then
  _err "有 ${fail_count} 个文件下载失败"
  exit 1
fi

# ── Install binary ──

cp "${INSTALL_DIR}/walrus" "${INSTALL_BIN}"
chmod +x "${INSTALL_BIN}"

_ok "文件下载完成 (${#FILES[@]} 个)"

# ── Verify ──

if walrus version &>/dev/null; then
  VERSION=$(walrus version)
  _ok "已安装: ${VERSION}"
else
  _err "安装验证失败"
  exit 1
fi

_ok "数据目录: ${INSTALL_DIR}"

# ── Done ──

printf "\n ${C_GREEN}${C_BOLD}安装完成!${C_RESET} 🦭\n\n"

printf " ${C_BOLD}下一步${C_RESET}\n\n"
printf "   ${C_DIM}# 1. 配置 R2 存储${C_RESET}\n"
printf "   walrus config\n\n"
printf "   ${C_DIM}# 2. 注册项目${C_RESET}\n"
printf "   walrus init\n\n"
printf "   ${C_DIM}# 查看帮助${C_RESET}\n"
printf "   walrus help\n\n"
