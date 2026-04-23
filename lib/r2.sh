#!/usr/bin/env bash
#
# walrus - remote storage operations
# rclone wrapper for S3-compatible storage (R2, S3, MinIO, etc.)

ensure_rclone() {
  if command -v rclone &>/dev/null; then
    return 0
  fi
  log_run "Installing rclone..."
  curl -sSL https://rclone.org/install.sh | bash >/dev/null 2>&1
  command -v rclone &>/dev/null || die "rclone installation failed"
  log_ok "rclone installed"
}

r2_is_configured() {
  command -v rclone &>/dev/null && \
    rclone listremotes 2>/dev/null | grep -q "^${WALRUS_R2_REMOTE}:$"
}

r2_check_connection() {
  local bucket
  bucket=$(r2_default_bucket)
  rclone lsf "${WALRUS_R2_REMOTE}:${bucket}/" --max-depth 1 --contimeout 5s --timeout 10s &>/dev/null \
    || rclone lsd "${WALRUS_R2_REMOTE}:" --contimeout 5s --timeout 10s &>/dev/null
}

r2_ensure_bucket() {
  local bucket="$1"
  if ! rclone lsd "${WALRUS_R2_REMOTE}:" 2>/dev/null | grep -qw "$bucket"; then
    rclone mkdir "${WALRUS_R2_REMOTE}:${bucket}" 2>/dev/null
  fi
}

r2_default_bucket() {
  local bucket_file="${WALRUS_CONF_DIR}/.default_bucket"
  if [[ -f "$bucket_file" ]]; then
    cat "$bucket_file"
  else
    echo "${WALRUS_DEFAULT_BUCKET}"
  fi
}

r2_save_default_bucket() {
  mkdir -p "${WALRUS_CONF_DIR}"
  echo "$1" > "${WALRUS_CONF_DIR}/.default_bucket"
}
