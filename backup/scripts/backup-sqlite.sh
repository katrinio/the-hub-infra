#!/usr/bin/env bash

# Infrastructure-managed SQLite backup for configured databases.

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

contains_unsafe_field_chars() {
  local value=${1:-}
  [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* || "${value}" == *'|'* ]]
}

safe_sqlite_quote() {
  local value=${1:-}
  value=${value//\'/\'\'}
  printf "'%s'" "${value}"
}

apply_sqlite_retention() {
  local backup_dir=$1
  local output_name=$2
  local retention_days=$3
  local file

  shopt -s nullglob
  for file in "${backup_dir}/${output_name}_"*.db; do
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_info "DRY_RUN=1: would evaluate retention for ${file}"
      continue
    fi
    if find "${file}" -type f -mtime +"${retention_days}" -print -quit | grep -q .; then
      rm -f -- "${file}"
      log_info "removed expired backup: ${file}"
    fi
  done
  shopt -u nullglob
}

backup_sqlite_database() {
  local system=$1
  local source_path=$2
  local output_name=$3
  local retention_days=$4
  local criticality=$5
  local timestamp final_file temp_file sql backup_size

  if contains_unsafe_field_chars "${system}" || contains_unsafe_field_chars "${source_path}" || contains_unsafe_field_chars "${output_name}" || contains_unsafe_field_chars "${retention_days}" || contains_unsafe_field_chars "${criticality}"; then
    log_error "unsafe characters found in config row for ${system}"
    return 1
  fi

  require_regular_file "${source_path}"
  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  final_file="${SQLITE_BACKUP_DIR}/${output_name}_${timestamp}.db"
  temp_file="${SQLITE_BACKUP_DIR}/.${output_name}_${timestamp}.tmp.db"
  sql=".backup $(safe_sqlite_quote "${temp_file}")"

  log_info "starting SQLite backup: system=${system} criticality=${criticality}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: would snapshot ${source_path} to ${final_file}"
    return 0
  fi

  trap 'cleanup_temp_file "${temp_file}"' ERR
  sqlite3 "${source_path}" "${sql}"

  if [[ ! -s "${temp_file}" ]]; then
    log_error "temporary backup is empty: ${temp_file}"
    cleanup_temp_file "${temp_file}"
    trap - ERR
    return 1
  fi

  if [[ "$(sqlite3 "${temp_file}" 'PRAGMA integrity_check;')" != "ok" ]]; then
    log_error "integrity check failed for temporary backup: ${temp_file}"
    cleanup_temp_file "${temp_file}"
    trap - ERR
    return 1
  fi

  mv -f -- "${temp_file}" "${final_file}"
  trap - ERR

  backup_size="$(wc -c < "${final_file}")"
  log_info "SQLite backup completed: ${final_file} (${backup_size} bytes)"
  apply_sqlite_retention "${SQLITE_BACKUP_DIR}" "${output_name}" "${retention_days}"
}

main() {
  local env_file="${BACKUP_ENV_FILE:-/etc/the-hub-backup/backup.env}"
  local sqlite_conf="${SQLITE_BACKUP_CONFIG:-/etc/the-hub-backup/sqlite.conf}"
  local line system source_path output_name retention_days criticality extra
  local failures=0 processed=0

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  else
    log_error "backup environment file not found: ${env_file}"
    return 1
  fi

  require_command sqlite3
  require_file "${sqlite_conf}"
  : "${SQLITE_BACKUP_DIR:?SQLITE_BACKUP_DIR is required}"
  : "${SQLITE_BACKUP_LOCK_FILE:?SQLITE_BACKUP_LOCK_FILE is required}"

  ensure_directory "${SQLITE_BACKUP_DIR}"
  acquire_lock "${SQLITE_BACKUP_LOCK_FILE}"
  trap release_lock EXIT

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    IFS='|' read -r system source_path output_name retention_days criticality extra <<< "${line}"
    if [[ -n "${extra:-}" || -z "${system}" || -z "${source_path}" || -z "${output_name}" || -z "${retention_days}" || -z "${criticality}" ]]; then
      log_error "invalid config line: ${line}"
      failures=$((failures + 1))
      continue
    fi
    if [[ ! "${retention_days}" =~ ^[0-9]+$ ]]; then
      log_error "invalid retention_days for ${system}: ${retention_days}"
      failures=$((failures + 1))
      continue
    fi

    processed=$((processed + 1))
    if ! backup_sqlite_database "${system}" "${source_path}" "${output_name}" "${retention_days}" "${criticality}"; then
      failures=$((failures + 1))
    fi
  done < "${sqlite_conf}"

  if (( processed == 0 )); then
    log_error "no SQLite backup entries found in ${sqlite_conf}"
    push_kuma_status "down" "sqlite backup failed: no entries configured"
    return 1
  fi

  if (( failures > 0 )); then
    log_error "sqlite backup finished with ${failures} failure(s)"
    push_kuma_status "down" "sqlite backup finished with failures"
    return 1
  fi

  log_info "sqlite backup finished successfully"
  push_kuma_status "up" "sqlite backup finished successfully"
}

main "$@"
