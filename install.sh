#!/bin/bash
set -euo pipefail

# ============================================================
#  walrus 远程安装脚本
#  curl -sSL https://raw.githubusercontent.com/layfz/walrus/main/install.sh | bash
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${BOLD}"
cat << 'ART'

  ██╗    ██╗ █████╗ ██╗     ██████╗ ██╗   ██╗███████╗
  ██║    ██║██╔══██╗██║     ██╔══██╗██║   ██║██╔════╝
  ██║ █╗ ██║███████║██║     ██████╔╝██║   ██║███████╗
  ██║███╗██║██╔══██║██║     ██╔══██╗██║   ██║╚════██║
  ╚███╔███╔╝██║  ██║███████╗██║  ██║╚██████╔╝███████║
   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
ART
echo -e "${NC}"
echo -e "  ${DIM}Installing walrus - PostgreSQL backup buddy for indie hackers${NC}"
echo ""

# 检测 root
if [ "$(id -u)" -ne 0 ]; then
  echo -e " ${RED}✗${NC} 请使用 root 用户运行"
  echo -e "   ${DIM}sudo bash -c \"\$(curl -sSL https://raw.githubusercontent.com/layfz/walrus/main/install.sh)\"${NC}"
  exit 1
fi

# 下载 walrus 主程序
echo -e " ${CYAN}→${NC} 下载 walrus..."

DOWNLOAD_URL="https://raw.githubusercontent.com/layfz/walrus/main/walrus"

if command -v curl &>/dev/null; then
  curl -sSL "$DOWNLOAD_URL" -o /usr/local/bin/walrus
elif command -v wget &>/dev/null; then
  wget -qO /usr/local/bin/walrus "$DOWNLOAD_URL"
else
  echo -e " ${RED}✗${NC} 需要 curl 或 wget"
  exit 1
fi

chmod +x /usr/local/bin/walrus

# 创建数据目录
mkdir -p /opt/walrus/{conf,data,logs}

echo -e " ${GREEN}✓${NC} walrus 已安装到 /usr/local/bin/walrus"
echo ""
echo -e " ${GREEN}${BOLD}安装完成！${NC} 🦭"
echo ""
echo -e "  开始使用:"
echo ""
echo -e "  ${DIM}walrus init \\${NC}"
echo -e "  ${DIM}  --project myapp \\${NC}"
echo -e "  ${DIM}  --container postgres \\${NC}"
echo -e "  ${DIM}  --user myuser \\${NC}"
echo -e "  ${DIM}  --db mydb \\${NC}"
echo -e "  ${DIM}  --r2-access-key <key> \\${NC}"
echo -e "  ${DIM}  --r2-secret-key <secret> \\${NC}"
echo -e "  ${DIM}  --r2-endpoint <endpoint>${NC}"
echo ""
echo -e "  更多命令: ${BOLD}walrus help${NC}"
echo ""
