#!/usr/bin/env bash

# Validation checks for infrastructure-managed PostgreSQL dumps.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"

file_mtime_epoch() {
  local file=$1
  stat -f '%m' "${file}" 2>/dev/null || stat -c '%Y' "${file}"
}

postgres_backup_subdir() {
  local output_name=$1
  printf '%s/%s' "${POSTGRES_BACKUP_DIR}" "${output_name}"
}

latest_dump_for_prefix() {
  local backup_dir=$1
  local latest=""
  local file

  shopt -s nullglob
  for file in "${backup_dir}"/*.dump; do
    latest="${file}"
  done
  shopt -u nullglob

  if [[ -n "${latest}" ]]; then
    printf '%s\n' "${latest}"
  fi
}

check_dump() {
  local system=$1
  local output_name=$2
  local backup_dir latest_dump age_hours now mtime

  backup_dir="$(postgres_backup_subdir "${output_name}")"
  latest_dump="$(latest_dump_for_prefix "${backup_dir}")"

  if [[ -z "${latest_dump}" ]]; then
    log_error "no dump found for ${system} (${output_name})"
    return 1
  fi

  if [[ ! -s "${latest_dump}" ]]; then
    log_error "dump is empty: ${latest_dump}"
    return 1
  fi

  mtime="$(file_mtime_epoch "${latest_dump}")"
  now="$(date '+%s')"
  age_hours=$(( (now - mtime) / 3600 ))
  if (( age_hours > POSTGRES_MAX_BACKUP_AGE_HOURS )); then
    log_error "dump is too old: ${latest_dump} (${age_hours}h)"
    return 1
  fi

  if command -v pg_restore >/dev/null 2>&1; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log_info "DRY_RUN=1: would run pg_restore --list ${latest_dump}"
    else
      pg_restore --list "${latest_dump}" >/dev/null
    fi
  else
    log_warn "pg_restore is not installed; skipping format validation"
  fi

  log_info "backup looks valid: ${latest_dump}"
}

main() {
  local env_file="${BACKUP_ENV_FILE:-/etc/the-hub-backup/backup.env}"
  local postgres_conf="${POSTGRES_BACKUP_CONFIG:-/etc/the-hub-backup/postgres.conf}"
  local line system container database user output_name criticality extra
  local failures=0 processed=0

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  else
    log_error "backup environment file not found: ${env_file}"
    return 1
  fi

  require_file "${postgres_conf}"
  : "${POSTGRES_BACKUP_DIR:?POSTGRES_BACKUP_DIR is required}"
  : "${POSTGRES_MAX_BACKUP_AGE_HOURS:?POSTGRES_MAX_BACKUP_AGE_HOURS is required}"

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
    if ! check_dump "${system}" "${output_name}"; then
      failures=$((failures + 1))
    fi
  done < "${postgres_conf}"

  if (( processed == 0 )); then
    log_error "no PostgreSQL backup entries found in ${postgres_conf}"
    return 1
  fi

  if (( failures > 0 )); then
    log_error "backup validation finished with ${failures} failure(s)"
    return 1
  fi

  log_info "backup validation finished successfully"
}

main "$@"
