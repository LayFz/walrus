#!/usr/bin/env bash
#
# walrus config - configure storage backend
# Supports R2, S3, MinIO, B2, and any existing rclone remote

cmd_config() {
  banner
  printf " ${C_BOLD}Configure Remote Storage${C_RESET}\n\n"

  ensure_rclone

  while true; do
    local existing_remotes
    existing_remotes=$(rclone listremotes 2>/dev/null | sed 's/:$//' || true)

    printf "   ${C_CYAN}1)${C_RESET} Cloudflare R2     ${C_DIM}Recommended, cheap with no egress fees${C_RESET}\n"
    printf "   ${C_CYAN}2)${C_RESET} Amazon S3\n"
    printf "   ${C_CYAN}3)${C_RESET} S3-compatible     ${C_DIM}MinIO / Alibaba OSS / Tencent COS etc.${C_RESET}\n"
    if [[ -n "$existing_remotes" ]]; then
      printf "   ${C_CYAN}4)${C_RESET} Use existing rclone remote\n"
    fi
    printf "   ${C_DIM}q) Quit${C_RESET}\n"
    echo ""

    ask "Select storage type" "1"
    local choice="$REPLY"
    echo ""

    case "$choice" in
      q|Q) return ;;
      1) _config_r2 && break ;;
      2) _config_s3 && break ;;
      3) _config_s3_compatible && break ;;
      4)
        if [[ -z "$existing_remotes" ]]; then
          log_err "No existing rclone remotes found"
          echo ""
          continue
        fi
        _config_existing "$existing_remotes" && break
        ;;
      *) log_err "Invalid choice"; echo ""; continue ;;
    esac
  done
}

# ── Cloudflare R2 ──

_config_r2() {
  printf " ${C_BOLD}Cloudflare R2${C_RESET}  ${C_DIM}(leave empty to go back)${C_RESET}\n\n"
  printf " ${C_DIM}Cloudflare Dashboard -> R2 -> Manage R2 API Tokens${C_RESET}\n\n"

  ask "Access Key ID" ""
  local access_key="$REPLY"
  [[ -n "$access_key" ]] || return 1

  ask "Secret Access Key" ""
  local secret_key="$REPLY"
  [[ -n "$secret_key" ]] || return 1

  ask "Endpoint URL (https://<account-id>.r2.cloudflarestorage.com)" ""
  local endpoint="$REPLY"
  [[ -n "$endpoint" ]] || return 1

  _config_bucket_and_verify \
    "provider=Cloudflare" \
    "access_key_id=${access_key}" \
    "secret_access_key=${secret_key}" \
    "endpoint=${endpoint}" \
    "acl=private" \
    "no_check_bucket=true"
}

# ── Amazon S3 ──

_config_s3() {
  printf " ${C_BOLD}Amazon S3${C_RESET}  ${C_DIM}(leave empty to go back)${C_RESET}\n\n"
  printf " ${C_DIM}AWS Console -> IAM -> Security Credentials -> Access Keys${C_RESET}\n\n"

  ask "Access Key ID" ""
  local access_key="$REPLY"
  [[ -n "$access_key" ]] || return 1

  ask "Secret Access Key" ""
  local secret_key="$REPLY"
  [[ -n "$secret_key" ]] || return 1

  ask "Region" "us-east-1"
  local region="$REPLY"

  _config_bucket_and_verify \
    "provider=AWS" \
    "access_key_id=${access_key}" \
    "secret_access_key=${secret_key}" \
    "region=${region}"
}

# ── S3 Compatible ──

_config_s3_compatible() {
  printf " ${C_BOLD}S3-compatible Storage${C_RESET}  ${C_DIM}(leave empty to go back)${C_RESET}\n\n"

  printf "   ${C_DIM}Common endpoint examples:${C_RESET}\n"
  printf "   ${C_DIM}MinIO:         http://your-server:9000${C_RESET}\n"
  printf "   ${C_DIM}Alibaba OSS:   https://oss-cn-hangzhou.aliyuncs.com${C_RESET}\n"
  printf "   ${C_DIM}Tencent COS:   https://cos.ap-guangzhou.myqcloud.com${C_RESET}\n"
  echo ""

  ask "Endpoint URL" ""
  local endpoint="$REPLY"
  [[ -n "$endpoint" ]] || return 1

  ask "Access Key ID" ""
  local access_key="$REPLY"
  [[ -n "$access_key" ]] || return 1

  ask "Secret Access Key" ""
  local secret_key="$REPLY"
  [[ -n "$secret_key" ]] || return 1

  ask "Region (leave empty for auto-detect)" ""
  local region="$REPLY"

  local params=(
    "provider=Other"
    "access_key_id=${access_key}"
    "secret_access_key=${secret_key}"
    "endpoint=${endpoint}"
    "no_check_bucket=true"
  )
  [[ -n "$region" ]] && params+=("region=${region}")

  _config_bucket_and_verify "${params[@]}"
}

# ── Use existing rclone remote ──

_config_existing() {
  local remotes="$1"
  printf " ${C_BOLD}Select existing rclone remote${C_RESET}  ${C_DIM}(leave empty to go back)${C_RESET}\n\n"

  local i=1
  while read -r name; do
    printf "   ${C_CYAN}%d)${C_RESET} %s\n" "$i" "$name"
    i=$((i + 1))
  done <<< "$remotes"
  echo ""

  ask "Choose" ""
  [[ -n "$REPLY" ]] || return 1

  local selected
  selected=$(echo "$remotes" | sed -n "${REPLY}p")
  [[ -n "$selected" ]] || { log_err "Invalid choice"; return 1; }

  if [[ "$selected" != "${WALRUS_R2_REMOTE}" ]]; then
    rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1 || true
    local conf_dir
    conf_dir="$(dirname "$RCLONE_CONFIG")"
    mkdir -p "$conf_dir"
    rclone config create "${WALRUS_R2_REMOTE}" alias remote="${selected}:" >/dev/null 2>&1
  fi

  echo ""
  ask "Default bucket name" "$(r2_default_bucket)"
  local bucket="$REPLY"

  echo ""
  log_run "Verifying connection..."

  if ! r2_check_connection; then
    rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1
    log_err "Connection failed, please check remote '${selected}' configuration"
    echo ""
    return 1
  fi

  r2_ensure_bucket "$bucket"
  r2_save_default_bucket "$bucket"

  _config_done
  _config_next
}

# ── Common: bucket + verify + save ──

_config_bucket_and_verify() {
  local params=("$@")

  echo ""
  ask "Default bucket name" "$(r2_default_bucket)"
  local bucket="$REPLY"

  echo ""
  log_run "Verifying connection..."

  _write_remote "${params[@]}"

  if ! r2_check_connection; then
    rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1
    log_err "Connection failed, please check credentials and endpoint"
    echo ""
    if confirm "Re-enter?"; then
      echo ""
      return 1
    fi
    exit 1
  fi

  r2_ensure_bucket "$bucket"
  r2_save_default_bucket "$bucket"

  _config_done
  _config_next
}

# ── Write rclone remote config ──

_write_remote() {
  local conf_dir
  conf_dir="$(dirname "$RCLONE_CONFIG")"
  mkdir -p "$conf_dir"

  if [[ -f "$RCLONE_CONFIG" ]] && [[ ! -w "$RCLONE_CONFIG" ]]; then
    die "Cannot write config: ${RCLONE_CONFIG}\n   Fix permissions: sudo chown \$(whoami) ${RCLONE_CONFIG}"
  fi

  rclone config delete "${WALRUS_R2_REMOTE}" >/dev/null 2>&1 || true

  # shellcheck disable=SC2068
  rclone config create "${WALRUS_R2_REMOTE}" s3 $@ >/dev/null 2>&1 \
    || die "Config write failed, check permissions: ${RCLONE_CONFIG}"
}

_config_done() {
  log_ok "Connection verified"
  echo ""
  printf " ${C_GREEN}${C_BOLD}Storage configured${C_RESET}\n\n"
}

_config_next() {
  if confirm "Continue to register a project?"; then
    echo ""
    cmd_init --from-config
  else
    echo ""
    log_dim "Run later: walrus init"
    echo ""
  fi
}
