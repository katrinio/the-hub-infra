#!/usr/bin/env bash

# Common shell helpers for backup scripts.

set -Eeuo pipefail

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

ensure_directory() {
  local dir_path=${1:-}
  if [[ -z "${dir_path}" ]]; then
    log_error "ensure_directory: missing directory path"
    return 1
  fi
  mkdir -p -- "${dir_path}"
}

cleanup() {
  log_info "cleanup requested"
}

acquire_lock() {
  local lock_name=${1:-}
  if [[ -z "${lock_name}" ]]; then
    log_error "acquire_lock: missing lock name"
    return 1
  fi
  log_info "lock placeholder: ${lock_name}"
}
