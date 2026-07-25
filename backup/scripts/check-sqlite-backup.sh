#!/usr/bin/env bash

# Validation checks for infrastructure-managed SQLite dumps.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

file_mtime_epoch() {
  local file=$1
  stat -f '%m' "${file}" 2>/dev/null || stat -c '%Y' "${file}"
}

latest_sqlite_backup() {
  local backup_dir=$1
  local output_name=$2
  local latest=""
  local file

  shopt -s nullglob
  for file in "${backup_dir}/${output_name}_"*.db; do
    latest="${file}"
  done
  shopt -u nullglob

  if [[ -n "${latest}" ]]; then
    printf '%s\n' "${latest}"
  fi
}

check_sqlite_backup() {
  local system=$1
  local output_name=$2
  local latest_dump now mtime age_hours integrity tables_count

  latest_dump="$(latest_sqlite_backup "${SQLITE_BACKUP_DIR}" "${output_name}")"
  if [[ -z "${latest_dump}" ]]; then
    log_error "no SQLite backup found for ${system} (${output_name})"
    return 1
  fi

  if [[ ! -s "${latest_dump}" ]]; then
    log_error "SQLite backup is empty: ${latest_dump}"
    return 1
  fi

  mtime="$(file_mtime_epoch "${latest_dump}")"
  now="$(date '+%s')"
  age_hours=$(( (now - mtime) / 3600 ))
  if (( age_hours > SQLITE_MAX_BACKUP_AGE_HOURS )); then
    log_error "SQLite backup is too old: ${latest_dump} (${age_hours}h)"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: would run integrity and table checks for ${latest_dump}"
    return 0
  fi

  integrity="$(sqlite3 "${latest_dump}" 'PRAGMA integrity_check;')"
  if [[ "${integrity}" != "ok" ]]; then
    log_error "integrity check failed for ${latest_dump}: ${integrity}"
    return 1
  fi

  tables_count="$(sqlite3 "${latest_dump}" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")"
  if [[ "${tables_count}" =~ ^[0-9]+$ ]] && (( tables_count > 0 )); then
    log_info "SQLite backup looks valid: ${latest_dump}"
    return 0
  fi

  log_error "no user tables found in ${latest_dump}"
  return 1
}

main() {
  local env_file="${BACKUP_ENV_FILE:-/etc/the-hub-backup/backup.env}"
  local sqlite_conf="${SQLITE_BACKUP_CONFIG:-/etc/the-hub-backup/sqlite.conf}"
  local line
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
  : "${SQLITE_MAX_BACKUP_AGE_HOURS:?SQLITE_MAX_BACKUP_AGE_HOURS is required}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    local system source_kind source_ref output_name retention_days criticality extra
    [[ -z "${line}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    IFS='|' read -r system source_kind source_ref output_name retention_days criticality extra <<< "${line}"
    if [[ -n "${extra:-}" ]]; then
      log_error "invalid config line: ${line}"
      failures=$((failures + 1))
      continue
    fi

    if [[ -z "${criticality:-}" ]]; then
      criticality="${retention_days:-}"
      retention_days="${output_name:-}"
      output_name="${source_ref:-}"
      source_ref="${source_kind:-}"
      source_kind="host_path"
    fi

    if [[ -z "${system}" || -z "${source_kind}" || -z "${source_ref}" || -z "${output_name}" || -z "${retention_days}" || -z "${criticality}" ]]; then
      log_error "invalid config line: ${line}"
      failures=$((failures + 1))
      continue
    fi

    processed=$((processed + 1))
    if ! check_sqlite_backup "${system}" "${output_name}"; then
      failures=$((failures + 1))
    fi
  done < "${sqlite_conf}"

  if (( processed == 0 )); then
    log_error "no SQLite backup entries found in ${sqlite_conf}"
    return 1
  fi

  if (( failures > 0 )); then
    log_error "SQLite backup validation finished with ${failures} failure(s)"
    return 1
  fi

  log_info "SQLite backup validation finished successfully"
}

main "$@"
