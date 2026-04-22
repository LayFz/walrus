#!/usr/bin/env bash
#
# walrus config - configure R2 storage connection

cmd_config() {
  banner
  printf " ${C_BOLD}配置 Cloudflare R2 存储${C_RESET}\n\n"

  require_root "config"
  ensure_rclone

  printf " ${C_DIM}请在 Cloudflare Dashboard → R2 → Manage R2 API Tokens 获取以下信息${C_RESET}\n\n"

  ask "Access Key ID" ""
  local access_key="$REPLY"
  [[ -n "$access_key" ]] || die "Access Key 不能为空"

  ask_secret "Secret Access Key"
  local secret_key="$REPLY"
  [[ -n "$secret_key" ]] || die "Secret Key 不能为空"

  ask "Endpoint URL (https://xxx.r2.cloudflarestorage.com)" ""
  local endpoint="$REPLY"
  [[ -n "$endpoint" ]] || die "Endpoint 不能为空"

  ask "默认 Bucket 名称" "$(r2_default_bucket)"
  local bucket="$REPLY"

  echo ""
  log_run "验证连接..."

  r2_configure "$access_key" "$secret_key" "$endpoint"

  if ! r2_check_connection; then
    rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1
    die "R2 连接失败，请检查凭证和 Endpoint"
  fi

  r2_ensure_bucket "$bucket"
  r2_save_default_bucket "$bucket"

  log_ok "R2 连接正常"
  echo ""
  printf " ${C_GREEN}${C_BOLD}R2 配置完成${C_RESET} 🦭\n\n"
  log_dim "下一步: walrus init"
  echo ""
}
