#!/usr/bin/env bash
#
# walrus - constants
# Global constants and version info

readonly WALRUS_VERSION="2.0.0"

# Paths
readonly WALRUS_HOME="/opt/walrus"
readonly WALRUS_CONF_DIR="${WALRUS_HOME}/conf"
readonly WALRUS_DATA_DIR="${WALRUS_HOME}/data"
readonly WALRUS_LOG_DIR="${WALRUS_HOME}/logs"
readonly WALRUS_LOCK_DIR="${WALRUS_HOME}/locks"

# R2
readonly WALRUS_R2_REMOTE="walrus_r2"

# Defaults
readonly WALRUS_DEFAULT_BWLIMIT="2M"
readonly WALRUS_DEFAULT_KEEP_DAYS=7
readonly WALRUS_DEFAULT_BUCKET="backup"
readonly WALRUS_DEFAULT_MAX_RATE="30M"

# Backup
readonly WALRUS_CONTAINER_WAL_DIR="/var/lib/postgresql/wal_archive"
readonly WALRUS_CONTAINER_TMP_DIR="/tmp/walrus_backup"
