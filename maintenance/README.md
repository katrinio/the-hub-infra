# Maintenance

Этот каталог содержит infrastructure-managed maintenance scripts и systemd units.

## Docker Build Cache Cleanup

Purpose: автоматически чистить unused Docker build cache и экспортировать результат в Prometheus metrics для Grafana.

Script:

```text
maintenance/scripts/cleanup-docker-build-cache.sh
```

Systemd:

```text
maintenance/systemd/the-hub-docker-build-cache-cleanup.service
maintenance/systemd/the-hub-docker-build-cache-cleanup.timer
```

Optional environment file:

```text
/etc/the-hub-maintenance/docker-build-cache.env
```

Template:

```text
maintenance/config/docker-build-cache.env.example
```

Schedule:

```text
OnCalendar=*-*-01,15 04:30:00
Persistent=true
RandomizedDelaySec=30m
```

Команда cleanup:

```bash
docker builder prune -af
```

Эта команда удаляет только то, что Docker Builder считает build cache. Она не является `docker system prune`, не удаляет Docker volumes, не удаляет stopped containers и не запускает `docker image prune`.

## Metrics

Metrics transport:

```text
cleanup script
  -> /var/lib/node_exporter/textfile_collector/docker-build-cache.prom
  -> node_exporter textfile collector
  -> Prometheus
  -> Grafana
```

Node exporter должен иметь host directory:

```text
/var/lib/node_exporter/textfile_collector
```

Recommended ownership and permissions on VPS:

```bash
sudo install -d -o root -g root -m 0755 /var/lib/node_exporter/textfile_collector
```

Metrics file:

```text
/var/lib/node_exporter/textfile_collector/docker-build-cache.prom
```

Implemented metrics:

```text
docker_build_cache_before_bytes
docker_build_cache_after_bytes
docker_build_cache_reclaimed_bytes
docker_build_cache_last_run_timestamp_seconds
docker_build_cache_last_success_timestamp_seconds
docker_build_cache_prune_success
docker_build_cache_cleanup_duration_seconds
```

Formula:

```text
docker_build_cache_reclaimed_bytes = max(docker_build_cache_before_bytes - docker_build_cache_after_bytes, 0)
```

Last cleanup age:

```promql
time() - docker_build_cache_last_run_timestamp_seconds
```

Last successful cleanup age:

```promql
time() - docker_build_cache_last_success_timestamp_seconds
```

Status:

```text
docker_build_cache_prune_success
```

Mapping:

- `1` = last real prune succeeded
- `0` = last attempt failed or was `DRY_RUN`

Metrics are written atomically: the script writes a temporary `.prom` file and renames it only after completing the output.

## Failure Behavior

If cache inspection before prune fails:

- the script does not run prune;
- writes failure metrics if the metrics directory is writable;
- exits non-zero.

If prune fails:

- writes `docker_build_cache_prune_success 0`;
- preserves pre-prune bytes if available;
- exits non-zero.

If inspection after prune fails:

- does not fabricate `after` or `reclaimed` values;
- writes failure metrics with the known pre-prune value;
- exits non-zero.

If metrics cannot be written:

- the script exits non-zero.

## Logs

The script writes concise INFO / WARN / ERROR lines to stdout and stderr.

The systemd service sends stdout/stderr to journald. Loki visibility depends on Alloy journal collection. Current Alloy config reads Docker container logs only, so systemd journal ingestion remains a separate monitoring follow-up.

Important log events:

- cleanup started;
- cache before cleanup;
- prune succeeded or failed;
- cache after cleanup;
- bytes reclaimed;
- metrics updated;
- failure reason.

No secrets are logged.

## Manual Execution

Dry run:

```bash
sudo DRY_RUN=1 /home/katrin/projects/the-hub-infra/maintenance/scripts/cleanup-docker-build-cache.sh
```

Real manual run:

```bash
sudo /home/katrin/projects/the-hub-infra/maintenance/scripts/cleanup-docker-build-cache.sh
```

Inspect generated metrics:

```bash
cat /var/lib/node_exporter/textfile_collector/docker-build-cache.prom
```

Inspect timer:

```bash
systemctl list-timers the-hub-docker-build-cache-cleanup.timer
systemctl status the-hub-docker-build-cache-cleanup.timer
```

Inspect last execution:

```bash
journalctl -u the-hub-docker-build-cache-cleanup.service -n 100 --no-pager
systemctl status the-hub-docker-build-cache-cleanup.service
```

Disable automation:

```bash
sudo systemctl disable --now the-hub-docker-build-cache-cleanup.timer
```
