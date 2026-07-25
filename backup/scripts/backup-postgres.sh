#!/usr/bin/env bash

# Infrastructure-managed PostgreSQL backup for configured databases.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

cleanup_temp_file() {
  local temp_file=${1:-}
  if [[ -n "${temp_file}" && -e "${temp_file}" ]]; then
    rm -f -- "${temp_file}"
    log_warn "removed temporary file: ${temp_file}"
  fi
}

container_is_running() {
  local container=$1
  local state
  state="$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null || true)"
  [[ "${state}" == "true" ]]
}

contains_unsafe_field_chars() {
  local value=${1:-}
  [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* || "${value}" == *'|'* ]]
}

postgres_backup_subdir() {
  local output_name=$1
  printf '%s/%s' "${POSTGRES_BACKUP_DIR}" "${output_name}"
}

backup_database() {
  local system=$1
  local container=$2
  local database=$3
  local user=$4
  local output_name=$5
  local criticality=$6
  local timestamp backup_dir final_file temp_file size_bytes

  if contains_unsafe_field_chars "${system}" || contains_unsafe_field_chars "${container}" || contains_unsafe_field_chars "${database}" || contains_unsafe_field_chars "${user}" || contains_unsafe_field_chars "${output_name}" || contains_unsafe_field_chars "${criticality}"; then
    log_error "unsafe characters found in config row for ${system}"
    return 1
  fi

  timestamp="$(TZ=UTC date '+%Y-%m-%dT%H-%M-%SZ')"
  backup_dir="$(postgres_backup_subdir "${output_name}")"
  final_file="${backup_dir}/${output_name}_${timestamp}.dump"
  temp_file="${backup_dir}/.${output_name}_${timestamp}.tmp.dump"

  log_info "database backup started: system=${system} database=${database} criticality=${criticality}"

  if ! container_is_running "${container}"; then
    log_error "container is not running: ${container}"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: would create ${final_file} from ${container}/${database}"
    return 0
  fi

  ensure_directory "${backup_dir}"

  trap 'cleanup_temp_file "${temp_file}"' ERR
  if ! docker exec "${container}" pg_dump -U "${user}" -d "${database}" -Fc > "${temp_file}"; then
    cleanup_temp_file "${temp_file}"
    trap - ERR
    log_error "error: backup failed for system=${system} database=${database}"
    return 1
  fi

  if [[ ! -s "${temp_file}" ]]; then
    log_error "error: temporary dump is empty: ${temp_file}"
    cleanup_temp_file "${temp_file}"
    trap - ERR
    return 1
  fi

  if ! docker exec -i "${container}" pg_restore --list < "${temp_file}" >/dev/null; then
    log_error "error: validation failed for system=${system} database=${database}"
    cleanup_temp_file "${temp_file}"
    trap - ERR
    return 1
  fi

  log_info "validation completed: system=${system} database=${database}"

  mv -f -- "${temp_file}" "${final_file}"
  trap - ERR

  size_bytes="$(wc -c < "${final_file}")"
  log_info "database backup completed: ${final_file} (${size_bytes} bytes)"
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
  : "${BACKUP_LOCK_FILE:?BACKUP_LOCK_FILE is required}"
  : "${KUMA_PUSH_URL_FILE:?KUMA_PUSH_URL_FILE is required}"

  ensure_directory "${POSTGRES_BACKUP_DIR}"
  acquire_lock "${BACKUP_LOCK_FILE}"
  trap release_lock EXIT

  log_info "starting PostgreSQL backup"

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

  log_info "all PostgreSQL backups completed"
  push_kuma_status "up" "postgres backup finished successfully"
}

main "$@"
