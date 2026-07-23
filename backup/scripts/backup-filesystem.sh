#!/usr/bin/env bash

# Safe scaffold for filesystem backup preparation.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

main() {
  local env_file="${BACKUP_ENV_FILE:-${script_dir}/../config/backup.env}"
  local filesystem_conf="${FILESYSTEM_BACKUP_CONFIG:-${script_dir}/../config/filesystem.conf}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_warn "DRY_RUN=1: no backup actions will be executed"
  fi

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  require_file "${filesystem_conf}"

  log_info "Filesystem backup scaffold loaded"
  log_info "TODO: prepare list of filesystem paths for restic"
  log_error "configuration is not filled in yet"
  return 1
}

main "$@"
