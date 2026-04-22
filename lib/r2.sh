#!/usr/bin/env bash
#
# walrus - R2 storage operations
# rclone wrapper for Cloudflare R2

# Ensure rclone is installed
ensure_rclone() {
  if command -v rclone &>/dev/null; then
    return 0
  fi
  log_run "安装 rclone..."
  curl -sSL https://rclone.org/install.sh | bash >/dev/null 2>&1
  command -v rclone &>/dev/null || die "rclone 安装失败"
  log_ok "rclone 安装完成"
}

# Check if R2 remote is configured
r2_is_configured() {
  command -v rclone &>/dev/null && \
    rclone listremotes 2>/dev/null | grep -q "^${WALRUS_R2_REMOTE}:$"
}

# Verify R2 connectivity
r2_check_connection() {
  rclone lsd "${WALRUS_R2_REMOTE}:" &>/dev/null
}

# Ensure a bucket exists
r2_ensure_bucket() {
  local bucket="$1"
  if ! rclone lsd "${WALRUS_R2_REMOTE}:" 2>/dev/null | grep -qw "$bucket"; then
    rclone mkdir "${WALRUS_R2_REMOTE}:${bucket}" 2>/dev/null
  fi
}

# Configure R2 remote with credentials
r2_configure() {
  local access_key="$1" secret_key="$2" endpoint="$3"

  if rclone listremotes 2>/dev/null | grep -q "^${WALRUS_R2_REMOTE}:$"; then
    rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1
  fi

  rclone config create "${WALRUS_R2_REMOTE}" s3 \
    provider=Cloudflare \
    access_key_id="$access_key" \
    secret_access_key="$secret_key" \
    endpoint="$endpoint" \
    acl=private \
    no_check_bucket=true \
    --quiet
}

# Get the saved default bucket name
r2_default_bucket() {
  local bucket_file="${WALRUS_CONF_DIR}/.default_bucket"
  if [[ -f "$bucket_file" ]]; then
    cat "$bucket_file"
  else
    echo "${WALRUS_DEFAULT_BUCKET}"
  fi
}

# Save default bucket name
r2_save_default_bucket() {
  mkdir -p "${WALRUS_CONF_DIR}"
  echo "$1" > "${WALRUS_CONF_DIR}/.default_bucket"
}
