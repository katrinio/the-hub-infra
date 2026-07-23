#!/usr/bin/env bash

# Safe scaffold that sequences individual backup steps.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

run_step() {
  local step_name=$1
  shift
  log_info "running ${step_name}"
  "$@"
}

main() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_warn "DRY_RUN=1: no backup actions will be executed"
  fi

  run_step "backup-postgres" "${script_dir}/backup-postgres.sh"
  run_step "backup-sqlite" "${script_dir}/backup-sqlite.sh"
  run_step "backup-filesystem" "${script_dir}/backup-filesystem.sh"
  run_step "backup-restic" "${script_dir}/backup-restic.sh"

  log_info "TODO: clean staging only after successful restic snapshot"
  log_error "configuration is not filled in yet"
  return 1
}

main "$@"
