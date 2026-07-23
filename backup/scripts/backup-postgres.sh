#!/usr/bin/env bash

# Infrastructure-managed PostgreSQL backup for configured databases.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

cleanup_partial_file() {
  local output_file=${1:-}
  if [[ -n "${output_file}" && -f "${output_file}" ]]; then
    rm -f -- "${output_file}"
    log_warn "removed incomplete dump: ${output_file}"
  fi
}

container_is_running() {
  local container=$1
  local state
  state="$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null || true)"
  [[ "${state}" == "true" ]]
}

apply_retention() {
  local backup_dir=$1
  local output_name=$2
  local retention_days=$3
  local pattern="${backup_dir}/${output_name}_"'*.dump'
  local file

  shopt -s nullglob
  for file in ${pattern}; do
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_info "DRY_RUN=1: would evaluate retention for ${file}"
      continue
    fi
    if find "${file}" -type f -mtime +"${retention_days}" -print -quit | grep -q .; then
      rm -f -- "${file}"
      log_info "removed expired dump: ${file}"
    fi
  done
  shopt -u nullglob
}

backup_database() {
  local system=$1
  local container=$2
  local database=$3
  local user=$4
  local output_name=$5
  local criticality=$6
  local timestamp output_file size_bytes

  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  output_file="${POSTGRES_BACKUP_DIR}/${output_name}_${timestamp}.dump"

  log_info "starting backup: system=${system} database=${database} criticality=${criticality}"

  if ! container_is_running "${container}"; then
    log_error "container is not running: ${container}"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: would create ${output_file} from ${container}/${database}"
    return 0
  fi

  trap 'cleanup_partial_file "${output_file}"' ERR
  if docker exec "${container}" pg_dump -U "${user}" -d "${database}" -Fc > "${output_file}"; then
    trap - ERR
  else
    cleanup_partial_file "${output_file}"
    trap - ERR
    log_error "backup failed: system=${system} database=${database}"
    return 1
  fi

  size_bytes="$(wc -c < "${output_file}")"
  log_info "backup completed: ${output_file} (${size_bytes} bytes)"
  apply_retention "${POSTGRES_BACKUP_DIR}" "${output_name}" "${POSTGRES_RETENTION_DAYS}"
  return 0
}

main() {
  local env_file="${BACKUP_ENV_FILE:-/etc/the-hub-backup/backup.env}"
  local postgres_conf="${POSTGRES_BACKUP_CONFIG:-/etc/the-hub-backup/postgres.conf}"
  local line system container database user output_name criticality
  local failures=0 processed=0

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  else
    log_error "backup environment file not found: ${env_file}"
    return 1
  fi

  require_command docker
  require_file "${postgres_conf}"

  : "${POSTGRES_BACKUP_DIR:?POSTGRES_BACKUP_DIR is required}"
  : "${POSTGRES_RETENTION_DAYS:?POSTGRES_RETENTION_DAYS is required}"
  : "${BACKUP_LOCK_FILE:?BACKUP_LOCK_FILE is required}"
  : "${KUMA_PUSH_URL_FILE:?KUMA_PUSH_URL_FILE is required}"

  ensure_directory "${POSTGRES_BACKUP_DIR}"
  acquire_lock "${BACKUP_LOCK_FILE}"
  trap release_lock EXIT

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    IFS='|' read -r system container database user output_name criticality extra <<< "${line}"
    if [[ -n "${extra:-}" || -z "${system}" || -z "${container}" || -z "${database}" || -z "${user}" || -z "${output_name}" || -z "${criticality}" ]]; then
      log_error "invalid config line: ${line}"
      failures=$((failures + 1))
      continue
    fi

    processed=$((processed + 1))
    if ! backup_database "${system}" "${container}" "${database}" "${user}" "${output_name}" "${criticality}"; then
      failures=$((failures + 1))
    fi
  done < "${postgres_conf}"

  if (( processed == 0 )); then
    log_error "no PostgreSQL backup entries found in ${postgres_conf}"
    push_kuma_status "down" "postgres backup failed: no entries configured"
    return 1
  fi

  if (( failures > 0 )); then
    log_error "postgres backup finished with ${failures} failure(s)"
    push_kuma_status "down" "postgres backup finished with failures"
    return 1
  fi

  log_info "postgres backup finished successfully"
  push_kuma_status "up" "postgres backup finished successfully"
}

main "$@"
