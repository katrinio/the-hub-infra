#!/usr/bin/env bash

# Safe scaffold for restic orchestration.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

main() {
  local env_file="${BACKUP_ENV_FILE:-${script_dir}/../config/backup.env}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_warn "DRY_RUN=1: no backup actions will be executed"
  fi

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  if [[ -z "${RESTIC_REPOSITORY:-}" || "${RESTIC_REPOSITORY:-}" == "TODO" ]]; then
    log_error "RESTIC_REPOSITORY is required"
    return 1
  fi

  if [[ -z "${RESTIC_PASSWORD_FILE:-}" || "${RESTIC_PASSWORD_FILE:-}" == "TODO" ]]; then
    log_error "RESTIC_PASSWORD_FILE is required"
    return 1
  fi

  require_file "${RESTIC_PASSWORD_FILE}"

  log_info "restic scaffold loaded"
  log_info "TODO: restic backup"
  log_info "TODO: restic forget/prune"
  log_error "configuration is not filled in yet"
  return 1
}

main "$@"
