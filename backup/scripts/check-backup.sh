#!/usr/bin/env bash

# Safe scaffold for backup validation checks.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

main() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_warn "DRY_RUN=1: no backup actions will be executed"
  fi

  log_info "TODO: restic check"
  log_info "TODO: verify freshness of the latest snapshot"
  log_info "TODO: test restore into restore-test"
  log_error "configuration is not filled in yet"
  return 1
}

main "$@"
