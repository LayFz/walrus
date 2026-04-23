#!/usr/bin/env bash
#
# walrus - constants
# Global constants and version info

readonly WALRUS_VERSION="dev"

# Platform
readonly WALRUS_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"  # linux / darwin

# Paths — ~/.walrus for normal users, /opt/walrus if running as root
if [[ "$(id -u)" -eq 0 ]]; then
  readonly WALRUS_HOME="/opt/walrus"
else
  readonly WALRUS_HOME="${HOME}/.walrus"
fi
readonly WALRUS_CONF_DIR="${WALRUS_HOME}/conf"
readonly WALRUS_DATA_DIR="${WALRUS_HOME}/data"
readonly WALRUS_LOG_DIR="${WALRUS_HOME}/logs"
readonly WALRUS_LOCK_DIR="${WALRUS_HOME}/locks"

# R2
readonly WALRUS_R2_REMOTE="walrus_r2"

# Rclone config: respect user's existing RCLONE_CONFIG > default location > walrus own
if [[ -n "${RCLONE_CONFIG:-}" ]] && [[ -f "$RCLONE_CONFIG" ]]; then
  : # User-configured, keep as-is
elif [[ -f "${HOME}/.config/rclone/rclone.conf" ]]; then
  export RCLONE_CONFIG="${HOME}/.config/rclone/rclone.conf"
else
  export RCLONE_CONFIG="${WALRUS_HOME}/conf/rclone.conf"
fi

# Defaults
readonly WALRUS_DEFAULT_BWLIMIT="2M"
readonly WALRUS_DEFAULT_KEEP_DAYS=7
readonly WALRUS_DEFAULT_BUCKET="backup"
readonly WALRUS_DEFAULT_MAX_RATE="30M"

# Docker WAL archive path (inside container)
readonly WALRUS_CONTAINER_WAL_DIR="/var/lib/postgresql/wal_archive"
