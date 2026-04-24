#!/usr/bin/env bash
#
# walrus update - self-update to the latest version

cmd_update() {
  local REPO="LayFz/walrus"
  local GITHUB_API="https://api.github.com/repos/${REPO}"

  local current="${WALRUS_VERSION}"

  log_run "Checking for updates..."

  local latest
  latest=$(curl -sSL "${GITHUB_API}/releases/latest" 2>/dev/null \
    | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

  if [[ -z "$latest" ]]; then
    die "Could not fetch latest version, check your network"
  fi

  if [[ "$current" == "$latest" ]]; then
    log_ok "Already up to date (v${current})"
    return
  fi

  printf "\n ${C_BOLD}Update available${C_RESET}\n\n"
  log_dim "Current: v${current}"
  log_dim "Latest:  v${latest}"
  echo ""

  if ! confirm "Update now?"; then
    echo "  Cancelled"
    return
  fi
  echo ""

  # Download
  local tarball_url="https://github.com/${REPO}/releases/download/v${latest}/walrus-${latest}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  log_run "Downloading v${latest}..."
  local http_code
  http_code=$(curl -sSL -w "%{http_code}" "$tarball_url" -o "${tmp_dir}/walrus.tar.gz")
  if [[ "$http_code" != "200" ]]; then
    rm -rf "$tmp_dir"
    die "Download failed (HTTP ${http_code})"
  fi

  # Verify checksum
  local checksum_url="${tarball_url}.sha256"
  curl -sSL "$checksum_url" -o "${tmp_dir}/walrus.tar.gz.sha256" 2>/dev/null || true
  if [[ -s "${tmp_dir}/walrus.tar.gz.sha256" ]]; then
    local expected actual
    expected=$(awk '{print $1}' "${tmp_dir}/walrus.tar.gz.sha256")
    actual=$(sha256sum "${tmp_dir}/walrus.tar.gz" 2>/dev/null | awk '{print $1}' \
      || shasum -a 256 "${tmp_dir}/walrus.tar.gz" | awk '{print $1}')
    if [[ "$expected" != "$actual" ]]; then
      rm -rf "$tmp_dir"
      die "Checksum verification failed!"
    fi
    log_ok "Checksum verified"
  fi

  # Extract and install
  tar xzf "${tmp_dir}/walrus.tar.gz" -C "$tmp_dir"

  local install_dir
  if [[ "$(id -u)" -eq 0 ]]; then
    install_dir="/opt/walrus"
  else
    install_dir="${HOME}/.walrus"
  fi

  cp -f "${tmp_dir}"/walrus/walrus "${install_dir}/walrus"
  cp -f "${tmp_dir}"/walrus/lib/* "${install_dir}/lib/"
  cp -f "${tmp_dir}"/walrus/commands/* "${install_dir}/commands/"

  chmod +x "${install_dir}/walrus"
  find "${install_dir}/lib" "${install_dir}/commands" -name '*.sh' -exec chmod +x {} +

  # Update symlink
  local install_bin
  if [[ "$(id -u)" -eq 0 ]]; then
    install_bin="/usr/local/bin/walrus"
  else
    install_bin="${HOME}/.local/bin/walrus"
  fi
  cp -f "${install_dir}/walrus" "$install_bin"
  chmod +x "$install_bin"

  rm -rf "$tmp_dir"

  echo ""
  printf " ${C_GREEN}${C_BOLD}Updated to v${latest}${C_RESET}\n\n"
}
