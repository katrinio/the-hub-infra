#!/usr/bin/env bash

# Infrastructure-managed Docker build cache cleanup with Prometheus textfile metrics.

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
source "${repo_root}/backup/scripts/lib/common.sh"

METRIC_FILE_NAME="docker-build-cache.prom"

cleanup_temp_file() {
  local temp_file=${1:-}
  if [[ -n "${temp_file}" && -e "${temp_file}" ]]; then
    rm -f -- "${temp_file}"
    log_warn "removed temporary file: ${temp_file}"
  fi
}

size_to_bytes() {
  local raw=${1:-}
  local number unit

  if [[ "${raw}" =~ ^([0-9]+([.][0-9]+)?)(B|kB|MB|GB|TB)$ ]]; then
    number="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[3]}"
  else
    log_error "unsupported Docker build cache size format: ${raw}"
    return 1
  fi

  awk -v number="${number}" -v unit="${unit}" '
    BEGIN {
      multiplier = 1
      if (unit == "kB") multiplier = 1000
      else if (unit == "MB") multiplier = 1000 * 1000
      else if (unit == "GB") multiplier = 1000 * 1000 * 1000
      else if (unit == "TB") multiplier = 1000 * 1000 * 1000 * 1000
      printf "%.0f\n", number * multiplier
    }
  '
}

docker_build_cache_bytes() {
  local total=0
  local size bytes

  while IFS= read -r size; do
    [[ -z "${size}" ]] && continue
    bytes="$(size_to_bytes "${size}")"
    total=$((total + bytes))
  done < <(docker builder du --format '{{.Size}}')

  printf '%s\n' "${total}"
}

write_metrics() {
  local success=$1
  local timestamp=$2
  local duration=$3
  local before_bytes=${4:-}
  local after_bytes=${5:-}
  local reclaimed_bytes=${6:-}
  local last_success_timestamp=${7:-}
  local metrics_dir="${DOCKER_BUILD_CACHE_METRICS_DIR}"
  local final_file="${metrics_dir}/${METRIC_FILE_NAME}"
  local temp_file="${metrics_dir}/.${METRIC_FILE_NAME}.$$"

  ensure_directory "${metrics_dir}"

  trap 'cleanup_temp_file "${temp_file}"' ERR
  {
    printf '# HELP docker_build_cache_before_bytes Docker build cache before the last cleanup attempt.\n'
    printf '# TYPE docker_build_cache_before_bytes gauge\n'
    if [[ -n "${before_bytes}" ]]; then
      printf 'docker_build_cache_before_bytes %s\n' "${before_bytes}"
    fi
    printf '# HELP docker_build_cache_after_bytes Docker build cache after the last successful cleanup.\n'
    printf '# TYPE docker_build_cache_after_bytes gauge\n'
    if [[ -n "${after_bytes}" ]]; then
      printf 'docker_build_cache_after_bytes %s\n' "${after_bytes}"
    fi
    printf '# HELP docker_build_cache_reclaimed_bytes Docker build cache bytes reclaimed by the last successful cleanup.\n'
    printf '# TYPE docker_build_cache_reclaimed_bytes gauge\n'
    if [[ -n "${reclaimed_bytes}" ]]; then
      printf 'docker_build_cache_reclaimed_bytes %s\n' "${reclaimed_bytes}"
    fi
    printf '# HELP docker_build_cache_last_run_timestamp_seconds Unix timestamp of the last completed cleanup attempt.\n'
    printf '# TYPE docker_build_cache_last_run_timestamp_seconds gauge\n'
    printf 'docker_build_cache_last_run_timestamp_seconds %s\n' "${timestamp}"
    printf '# HELP docker_build_cache_last_success_timestamp_seconds Unix timestamp of the last successful cleanup.\n'
    printf '# TYPE docker_build_cache_last_success_timestamp_seconds gauge\n'
    if [[ -n "${last_success_timestamp}" ]]; then
      printf 'docker_build_cache_last_success_timestamp_seconds %s\n' "${last_success_timestamp}"
    fi
    printf '# HELP docker_build_cache_prune_success Whether the last Docker build cache prune completed successfully.\n'
    printf '# TYPE docker_build_cache_prune_success gauge\n'
    printf 'docker_build_cache_prune_success %s\n' "${success}"
    printf '# HELP docker_build_cache_cleanup_duration_seconds Duration of the last cleanup attempt.\n'
    printf '# TYPE docker_build_cache_cleanup_duration_seconds gauge\n'
    printf 'docker_build_cache_cleanup_duration_seconds %s\n' "${duration}"
  } > "${temp_file}"

  mv -f -- "${temp_file}" "${final_file}"
  trap - ERR
}

previous_success_timestamp() {
  local file="${DOCKER_BUILD_CACHE_METRICS_DIR}/${METRIC_FILE_NAME}"
  local value=""

  if [[ -f "${file}" ]]; then
    value="$(awk '$1 == "docker_build_cache_last_success_timestamp_seconds" { print $2; exit }' "${file}")"
  fi

  if [[ "${value}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${value}"
  fi
}

main() {
  local env_file="${DOCKER_BUILD_CACHE_ENV_FILE:-/etc/the-hub-maintenance/docker-build-cache.env}"
  local start_timestamp end_timestamp duration
  local before_bytes="" after_bytes="" reclaimed_bytes="" last_success_timestamp=""
  local success=0

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  : "${DOCKER_BUILD_CACHE_METRICS_DIR:=/var/lib/node_exporter/textfile_collector}"
  : "${DOCKER_BUILD_CACHE_LOCK_FILE:=/tmp/the-hub-docker-build-cache-cleanup.lock}"

  require_command docker
  require_command awk

  acquire_lock "${DOCKER_BUILD_CACHE_LOCK_FILE}"
  trap release_lock EXIT

  start_timestamp="$(date '+%s')"
  last_success_timestamp="$(previous_success_timestamp || true)"

  log_info "Starting Docker build cache cleanup"

  if ! before_bytes="$(docker_build_cache_bytes)"; then
    end_timestamp="$(date '+%s')"
    duration=$((end_timestamp - start_timestamp))
    log_error "Docker build cache inspection before cleanup failed"
    write_metrics 0 "${end_timestamp}" "${duration}" "" "" "" "${last_success_timestamp}"
    return 1
  fi

  log_info "Build cache before cleanup: ${before_bytes} bytes"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN=1: skipping docker builder prune -af"
  elif ! docker builder prune -af >/dev/null; then
    end_timestamp="$(date '+%s')"
    duration=$((end_timestamp - start_timestamp))
    log_error "Docker build cache prune failed"
    write_metrics 0 "${end_timestamp}" "${duration}" "${before_bytes}" "" "" "${last_success_timestamp}"
    return 1
  else
    log_info "Docker build cache prune succeeded"
  fi

  if ! after_bytes="$(docker_build_cache_bytes)"; then
    end_timestamp="$(date '+%s')"
    duration=$((end_timestamp - start_timestamp))
    log_error "Docker build cache inspection after cleanup failed"
    write_metrics 0 "${end_timestamp}" "${duration}" "${before_bytes}" "" "" "${last_success_timestamp}"
    return 1
  fi

  if (( before_bytes > after_bytes )); then
    reclaimed_bytes=$((before_bytes - after_bytes))
  else
    reclaimed_bytes=0
  fi

  end_timestamp="$(date '+%s')"
  duration=$((end_timestamp - start_timestamp))

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    success=0
    log_info "DRY_RUN=1: metrics written with prune_success=0"
  else
    success=1
    last_success_timestamp="${end_timestamp}"
  fi

  log_info "Build cache after cleanup: ${after_bytes} bytes"
  log_info "Reclaimed: ${reclaimed_bytes} bytes"

  write_metrics "${success}" "${end_timestamp}" "${duration}" "${before_bytes}" "${after_bytes}" "${reclaimed_bytes}" "${last_success_timestamp}"
  log_info "Prometheus metrics updated"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi

  log_info "Cleanup completed successfully"
}

main "$@"
