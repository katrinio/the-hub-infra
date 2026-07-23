#!/usr/bin/env bash

# Common shell helpers for backup scripts.

set -Eeuo pipefail

LOCK_FD=""

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

require_command() {
  local command_name=${1:-}
  if [[ -z "${command_name}" ]]; then
    log_error "require_command: missing command name"
    return 1
  fi
  command -v "${command_name}" >/dev/null 2>&1 || {
    log_error "required command not found: ${command_name}"
    return 1
  }
}

require_file() {
  local file_path=${1:-}
  if [[ -z "${file_path}" ]]; then
    log_error "require_file: missing file path"
    return 1
  fi
  [[ -f "${file_path}" ]] || {
    log_error "required file not found: ${file_path}"
    return 1
  }
}

require_regular_file() {
  local file_path=${1:-}
  if [[ -z "${file_path}" ]]; then
    log_error "require_regular_file: missing file path"
    return 1
  fi
  [[ -f "${file_path}" ]] || {
    log_error "required regular file not found: ${file_path}"
    return 1
  }
}

ensure_directory() {
  local dir_path=${1:-}
  if [[ -z "${dir_path}" ]]; then
    log_error "ensure_directory: missing directory path"
    return 1
  fi
  mkdir -p -- "${dir_path}"
}

acquire_lock() {
  local lock_file=${1:-}
  if [[ -z "${lock_file}" ]]; then
    log_error "acquire_lock: missing lock file"
    return 1
  fi
  require_command flock
  ensure_directory "$(dirname "${lock_file}")"
  exec {LOCK_FD}>"${lock_file}"
  flock -n "${LOCK_FD}" || {
    log_error "failed to acquire lock: ${lock_file}"
    return 1
  }
}

release_lock() {
  if [[ -n "${LOCK_FD}" ]]; then
    flock -u "${LOCK_FD}" || true
    eval "exec ${LOCK_FD}>&-"
    LOCK_FD=""
  fi
}

push_kuma_status() {
  local status=${1:-}
  local message=${2:-}
  local url_file=${3:-${KUMA_PUSH_URL_FILE:-}}
  local url=""

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: skipping Kuma push (${status})"
    return 0
  fi

  if [[ -z "${url_file}" || ! -f "${url_file}" ]]; then
    log_warn "Kuma push URL file is missing; skipping push"
    return 0
  fi

  url="$(<"${url_file}")"
  if [[ -z "${url}" ]]; then
    log_warn "Kuma push URL is empty; skipping push"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is not installed; skipping Kuma push"
    return 0
  fi

  curl --fail --silent --show-error \
    --max-time 10 \
    --data-urlencode "msg=${message}" \
    "${url}?status=${status}" >/dev/null || {
    log_warn "failed to push backup status to Kuma"
    return 0
  }
}
