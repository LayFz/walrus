#!/usr/bin/env bash
#
# walrus - terminal colors
# Auto-detects terminal capability and provides color variables

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RED=$'\033[0;31m'
  readonly C_GREEN=$'\033[0;32m'
  readonly C_YELLOW=$'\033[1;33m'
  readonly C_CYAN=$'\033[0;36m'
  readonly C_BOLD=$'\033[1m'
  readonly C_DIM=$'\033[2m'
  readonly C_RESET=$'\033[0m'
else
  readonly C_RED="" C_GREEN="" C_YELLOW="" C_CYAN=""
  readonly C_BOLD="" C_DIM="" C_RESET=""
fi
