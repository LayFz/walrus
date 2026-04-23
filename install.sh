#!/usr/bin/env bash
#
# walrus installer
# curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
#
# Options:
#   WALRUS_VERSION=2.1.0  Install a specific version (default: latest)
#

set -euo pipefail

readonly REPO="LayFz/walrus"
readonly GITHUB_API="https://api.github.com/repos/${REPO}"

# Root -> /opt/walrus + /usr/local/bin, otherwise -> ~/.walrus + ~/.local/bin
if [[ "$(id -u)" -eq 0 ]]; then
  readonly INSTALL_DIR="/opt/walrus"
  readonly INSTALL_BIN="/usr/local/bin/walrus"
else
  readonly INSTALL_DIR="${HOME}/.walrus"
  readonly INSTALL_BIN="${HOME}/.local/bin/walrus"
fi

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

# ── Path setup ──

mkdir -p "$(dirname "$INSTALL_BIN")"

# ── Resolve version ──

if [[ -z "${WALRUS_VERSION:-}" ]]; then
  _run "Fetching latest version..."
  if command -v curl &>/dev/null; then
    WALRUS_VERSION=$(curl -sSL "${GITHUB_API}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  elif command -v wget &>/dev/null; then
    WALRUS_VERSION=$(wget -qO- "${GITHUB_API}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  else
    _err "curl or wget required"
    exit 1
  fi

  if [[ -z "$WALRUS_VERSION" ]]; then
    _err "Could not determine latest version. Check network or specify: WALRUS_VERSION=x.y.z"
    exit 1
  fi
fi

_ok "Version: v${WALRUS_VERSION}"

# ── Download tarball ──

TARBALL_URL="https://github.com/${REPO}/releases/download/v${WALRUS_VERSION}/walrus-${WALRUS_VERSION}.tar.gz"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

_run "Downloading walrus v${WALRUS_VERSION}..."

if command -v curl &>/dev/null; then
  HTTP_CODE=$(curl -sSL -w "%{http_code}" "$TARBALL_URL" -o "${TMP_DIR}/walrus.tar.gz")
  if [[ "$HTTP_CODE" != "200" ]]; then
    _err "Download failed (HTTP ${HTTP_CODE})"
    _err "URL: ${TARBALL_URL}"
    printf "\n   ${C_DIM}Available versions: https://github.com/${REPO}/releases${C_RESET}\n\n"
    exit 1
  fi
elif command -v wget &>/dev/null; then
  if ! wget -qO "${TMP_DIR}/walrus.tar.gz" "$TARBALL_URL"; then
    _err "Download failed"
    _err "URL: ${TARBALL_URL}"
    printf "\n   ${C_DIM}Available versions: https://github.com/${REPO}/releases${C_RESET}\n\n"
    exit 1
  fi
fi

_ok "Download complete"

# ── Verify checksum (optional) ──

_run "Verifying integrity..."
CHECKSUM_URL="${TARBALL_URL}.sha256"
if command -v curl &>/dev/null; then
  curl -sSL "$CHECKSUM_URL" -o "${TMP_DIR}/walrus.tar.gz.sha256" 2>/dev/null || true
elif command -v wget &>/dev/null; then
  wget -qO "${TMP_DIR}/walrus.tar.gz.sha256" "$CHECKSUM_URL" 2>/dev/null || true
fi

if [[ -s "${TMP_DIR}/walrus.tar.gz.sha256" ]]; then
  EXPECTED=$(awk '{print $1}' "${TMP_DIR}/walrus.tar.gz.sha256")
  ACTUAL=$(sha256sum "${TMP_DIR}/walrus.tar.gz" 2>/dev/null | awk '{print $1}' || shasum -a 256 "${TMP_DIR}/walrus.tar.gz" | awk '{print $1}')
  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    _err "Checksum verification failed! File may have been tampered with"
    _err "Expected: ${EXPECTED}"
    _err "Actual:   ${ACTUAL}"
    exit 1
  fi
  _ok "SHA256 checksum verified"
else
  _ok "Skipping checksum (not found)"
fi

# ── Extract and install ──

_run "Installing to ${INSTALL_DIR}..."

tar xzf "${TMP_DIR}/walrus.tar.gz" -C "$TMP_DIR"

mkdir -p "${INSTALL_DIR}"/{conf,data,logs,locks,lib,commands}

cp -f "${TMP_DIR}"/walrus/walrus "${INSTALL_DIR}/walrus"
cp -f "${TMP_DIR}"/walrus/lib/* "${INSTALL_DIR}/lib/"
cp -f "${TMP_DIR}"/walrus/commands/* "${INSTALL_DIR}/commands/"

chmod +x "${INSTALL_DIR}/walrus"
find "${INSTALL_DIR}/lib" "${INSTALL_DIR}/commands" -name '*.sh' -exec chmod +x {} +

cp -f "${INSTALL_DIR}/walrus" "${INSTALL_BIN}"
chmod +x "${INSTALL_BIN}"

_ok "Files installed"

# ── Install postgresql-client if missing ──

if ! command -v psql &>/dev/null; then
  _run "Installing PostgreSQL client tools..."
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq postgresql-client >/dev/null 2>&1
  elif command -v yum &>/dev/null; then
    yum install -y -q postgresql >/dev/null 2>&1
  elif command -v dnf &>/dev/null; then
    dnf install -y -q postgresql >/dev/null 2>&1
  elif command -v apk &>/dev/null; then
    apk add --quiet postgresql-client >/dev/null 2>&1
  elif command -v brew &>/dev/null; then
    brew install --quiet libpq >/dev/null 2>&1
    brew link --force libpq >/dev/null 2>&1
  fi

  if command -v psql &>/dev/null; then
    _ok "PostgreSQL client installed"
  else
    _err "PostgreSQL client auto-install failed, please install postgresql-client manually"
  fi
else
  _ok "PostgreSQL client found"
fi

# ── Verify ──

if "${INSTALL_BIN}" version &>/dev/null; then
  VERSION=$("${INSTALL_BIN}" version)
  _ok "Installed: ${VERSION}"
else
  _err "Installation verification failed"
  exit 1
fi

_ok "Data directory: ${INSTALL_DIR}"

# ── PATH check ──

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$(dirname "$INSTALL_BIN")"; then
  echo ""
  _run "Add the following to your PATH:"
  printf "   export PATH=\"%s:\$PATH\"\n" "$(dirname "$INSTALL_BIN")"
fi

# ── Done ──

printf "\n ${C_GREEN}${C_BOLD}Installation complete!${C_RESET}\n\n"

printf " ${C_BOLD}Next steps${C_RESET}\n\n"
printf "   ${C_DIM}# 1. Configure R2 storage${C_RESET}\n"
printf "   walrus config\n\n"
printf "   ${C_DIM}# 2. Register a project${C_RESET}\n"
printf "   walrus init\n\n"
printf "   ${C_DIM}# View help${C_RESET}\n"
printf "   walrus help\n\n"
