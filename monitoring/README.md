# Monitoring And Grafana Dashboards

Этот документ является source of truth для Grafana dashboards, datasource responsibilities и metric catalog в `the-hub-infra`.

Dashboard configuration в Grafana не должен быть единственным местом, где описаны смысл панели, источник данных и формула. Формулы, PromQL, LogQL, labels и статус метрик должны сначала фиксироваться здесь, а затем переноситься в provisioned dashboards.

## Current Monitoring Stack

Фактически описано в репозитории:

- `monitoring/compose.yaml` поднимает `Grafana`, `Prometheus`, `Loki`, `Alloy`, `node-exporter`, `cadvisor`.
- `monitoring/config/prometheus/prometheus.yml` scrape'ит `prometheus`, `node-exporter`, `cadvisor`.
- `monitoring/config/loki/local-config.yaml` задаёт Loki single-node filesystem storage и explicit retention.
- `monitoring/config/alloy/config.alloy` читает Docker container logs через Docker socket и отправляет их в `Loki`.
- `docker/monitoring.compose.yml`, `docker/prometheus.yml` и `docker/alloy-config.alloy` являются похожей monitoring-конфигурацией старого layout. В ней нет `cadvisor` и нет явных networks.
- Grafana dashboards созданы и работают в самой Grafana (folder `The Hub`, Grafana 13.1.0 OSS), но provisioning/JSON files в репозитории пока не сохранены. Актуальное состояние см. в разделе "Current Grafana Implementation".
- `Uptime Kuma` описан отдельно в `docker/uptime-kuma.compose.yml`.
- Backup scripts пишут human-readable logs и отправляют heartbeat в Uptime Kuma Push monitors, но не экспортируют Prometheus metrics.

## Current Grafana Implementation

Фактическое состояние Grafana на 2026-07-25, Grafana `13.1.0` OSS.

Datasources, используемые dashboards:

- Prometheus — uid `afpxbacgo8tmod`, url `http://prometheus:9090`.
- Loki — uid `bfpx8fz5l1j40d`, url `http://loki:3100` (default datasource).
- PostgreSQL — `grafana-postgresql-datasource`, `grafana-postgresql-finpipe` (для FinPipe dashboards, вне scope этого документа).

Folder `The Hub` (uid `dft7iaru6t8u8a`) содержит dashboards, созданные вручную через Grafana API:

| Dashboard | uid | Status |
|---|---|---|
| 00 Overview | `the-hub-00-overview` | implemented (infra + logs summary) |
| 10 Infrastructure | `the-hub-10-infra` | implemented |
| 15 Applications | `the-hub-15-apps` | implemented |
| 40 Logs / Operations | `the-hub-40-logs` | implemented |

Не созданы (нет метрик): `20 Backups`, `30 Services` — остаются instrumentation required.

Dashboards вне folder `The Hub` (существовали ранее, не трогались):

- `Cadvisor exporter` — сырой per-container drill-down с переменными `host` / `container`.
- `FinPipe`, `container_memory_usage_bytes`.

Удалён: `Infra / VPS` — его панели (CPU / RAM / Disk / Network / Load / Uptime) перенесены в `10 Infrastructure` (в Grafana Recently deleted ~30 дней).

### Backup / export (MVP)

Дашборды пока не под provisioning, но их JSON можно выгружать в git скриптом:

```bash
export GRAFANA_URL=https://grafana.finpipe.net
export GRAFANA_TOKEN=<service-account-token>   # роль Viewer достаточно
monitoring/config/grafana/export-dashboards.sh
```

Скрипт кладёт `dashboards/<uid>.json` (с обнулённым `id` и без `version` — для портируемости). Список uid внутри скрипта; при добавлении нового дашборда допиши uid туда. Полноценный provisioning (auto-load + read-only) — отдельный будущий шаг.

### Loki label reality

Alloy сейчас пишет Docker-логи в Loki одним stream'ом `service_name="unknown_service"` (плюс `detected_level`), без per-container и systemd labels. Поэтому LogQL-панели построены на текстовых фильтрах и `detected_level`, а не на стабильных labels `job` / `service` / `host`, описанных ниже как target-состояние. Для label-based queries требуется доработка Alloy pipeline (container labels + journal source).

Loki self-audit noise: контейнеры `grafana` и `loki` шлют свой stdout в Loki, поэтому error-панели исключают строки собственных запросов Loki фильтром `!= "query_hash="`.

Log format: у сервиса `grafana` в `monitoring/compose.yaml` выставлен `GF_LOG_CONSOLE_FORMAT=json` (вместо logfmt по умолчанию) — логи Grafana пишутся в JSON, чище парсятся в Loki по полям (`level`, `msg`, ...). Level оставлен `info`. Цветовая маркировка уровня и `detected_level` работают на обоих форматах. Каждый другой контейнер логирует в своём формате — эта настройка влияет только на Grafana.

## Retention Policy

Loki работает как single-node filesystem-backed service:

- image: `grafana/loki:3.7.0`
- config: `monitoring/config/loki/local-config.yaml`
- storage: Docker volume `monitoring_loki-data`, mounted as `/loki`
- schema: TSDB `v13`
- object storage: filesystem
- replication factor: `1`
- Loki retention: `720h` (`30 days`)

| Data | Owner | Storage | Retention / rotation |
|---|---|---|---|
| Loki logs | Loki | `monitoring_loki-data` | Current policy: `30 days` via `limits_config.retention_period: 720h` and Loki compactor retention |
| systemd journal | journald | host | Current policy: OS defaults. TODO: define explicit journald size/time limits |
| Docker json-file logs | Docker | host | Current policy: no explicit rotation in repository. TODO: configure Docker log rotation separately |
| Prometheus metrics | Prometheus | `monitoring_prometheus-data` | Current policy: Prometheus image/default retention because no `--storage.tsdb.retention.*` flag is configured. TODO: define explicit metrics retention |
| Grafana DB | Grafana | `monitoring_grafana-data` | Persistent. Protected by unified SQLite backup through `docker_cp:grafana:/var/lib/grafana/grafana.db` |

This task only makes Loki retention explicit. journald retention, Docker log rotation and Prometheus retention remain follow-up work.

## Architecture Diagram

```text
node-exporter ────────────────→ Prometheus ─┐
cadvisor ─────────────────────→ Prometheus ─┤
backup textfile metrics ──────→ Prometheus ─┤  planned / instrumentation required
docker-cache textfile metrics → Prometheus ─┤
                                            ├→ Grafana
Docker container logs ──→ Alloy ─→ Loki ────┤
systemd journal ────────→ Alloy ─→ Loki ────┤  planned / instrumentation required
Uptime Kuma ────────────────────────────────┘  heartbeat layer, not metric source of truth
```

## Datasource Responsibilities

### Prometheus

Prometheus является источником numeric state и time series:

- capacity и utilization;
- durations;
- counters и gauges;
- backup metrics;
- Docker build cache metrics;
- service-level numeric health, если сервисы будут instrumented.

### Loki

Loki является источником execution history и investigation context:

- ошибки;
- human-readable operational events;
- systemd service logs;
- backup execution logs;
- Docker cache cleanup logs;
- container logs.

Loki не должен быть primary source для числовых SLO/backup age/capacity panels, если эти значения можно экспортировать как Prometheus metrics.

### Uptime Kuma

Uptime Kuma отвечает за простой heartbeat и availability indication:

- PostgreSQL backup Push monitor;
- SQLite backup Push monitor;
- external service checks.

Uptime Kuma не является source of truth для Grafana historical metrics.

### Grafana

Grafana отвечает только за visualization:

- dashboards;
- panels;
- queries;
- links between metrics and logs.

Grafana не должен становиться source of truth для metric definitions.

## Dashboard Hierarchy

### 00 Overview

Purpose: один экран для ответа "инфраструктура сейчас здорова или нет?".

Operational questions:

- Есть ли активные backup failures?
- Не устарели ли последние backups?
- Есть ли критичный disk/memory/CPU pressure?
- Работают ли основные containers?
- Есть ли всплеск systemd/container errors?
- Нужен ли immediate investigation?

Status: implemented (частично). Реализованы infrastructure health, monitoring target health и recent errors из Loki. Backup status summary остаётся instrumentation required.

### 10 Infrastructure

Purpose: состояние VPS и Docker runtime.

Operational questions:

- Сколько disk space осталось?
- Есть ли memory pressure?
- Есть ли abnormal CPU usage?
- Растёт ли Docker resource usage?
- Все ли monitoring targets scrape'ятся?

Status: implemented. Панели: CPU / Memory / Disk (gauge с порогами 70/90), CPU / Memory trends с пороговой раскраской, Load average, Network traffic, Uptime, disk usage by mount (bar gauge), filesystem free bytes и Filesystem free (/), container CPU / memory (cAdvisor), Prometheus scrape health (table) и Target status. Load / Network / Uptime перенесены из удалённого `Infra / VPS`.

Секция `Docker build cache cleanup` (row внизу дашборда): bar gauge `before / after / reclaimed` (bytes IEC), stat `Last cleanup status` (`1` = Success / `0` = Failed), stat `Last successful cleanup age` (duration, пороги под twice-monthly расписание), stat `Cleanup duration` (seconds). Docker build cache — infrastructure/maintenance concern; в архитектуре он числится за `20 Backups`, но т.к. тот дашборд ещё не создан, панели добавлены сюда, а не в ad-hoc дашборд.

### 15 Applications

Purpose: сколько ресурсов занимает каждое приложение, без шума от инфраструктуры.

Реализация: контейнеры cAdvisor группируются по приложению через `label_replace` (label `name` -> `app`); вся инфраструктура свёрнута в один ряд `infra`.

Application mapping:

- `finpipe`: `finpipe-finpipe-web-1`, `finpipe-bot`, `finpipe-postgres-1`
- `echo`: `echo-app`
- `traect`: `traect`
- `registry`: `registry-web`
- `infra` (один aggregated series): `prometheus`, `cadvisor`, `loki`, `alloy`, `grafana`, `uptime-kuma`, `node-exporter`

Grouping PromQL (memory; для CPU заменить selector на `rate(container_cpu_usage_seconds_total{name!=""}[5m])`):

```promql
sum by (app) (
  label_replace(label_replace(label_replace(label_replace(label_replace(
    container_memory_working_set_bytes{name!=""},
    "app","infra","name",".+"),
    "app","finpipe","name","finpipe-.*"),
    "app","echo","name","echo-app"),
    "app","traect","name","traect"),
    "app","registry","name","registry-web"))
```

Panels: memory / CPU per application как Stat (now), Bar gauge (ranking) и stacked Time series (trend). Цвета приложений закреплены (pastel), `infra` — серый, чтобы визуально уходил в фон.

Status: implemented на текущих cAdvisor metrics.

### 20 Backups

Purpose: operational control plane для unified PostgreSQL и SQLite backups.

Operational questions:

- Когда был последний successful backup по каждой database/system?
- Насколько старый каждый backup?
- Последний запуск завершился успешно или с ошибкой?
- Какой размер backup?
- Сколько длился backup?
- Какие ошибки были в последнем запуске?
- Есть ли расхождение между Uptime Kuma heartbeat и Prometheus metrics?

Status: instrumentation required. Сейчас scripts логируют события и отправляют Kuma heartbeat, но не экспортируют Prometheus metrics.

### 30 Services

Purpose: состояние application/service-level monitoring.

Operational questions:

- Живы ли user-facing services?
- Есть ли service-specific error rate или latency?
- Есть ли application-level metrics для Finpipe, Yo Registry, Traect, Echo?

Status: planned / instrumentation required. В репозитории нет service-specific Prometheus instrumentation.

### 40 Logs / Operations

Purpose: investigation dashboards для operational events.

Operational questions:

- Какие backup jobs падали и почему?
- Какие errors были в Docker containers?
- Какие systemd units пишут errors?
- Когда запускался Docker build cache cleanup?
- Что произошло во время последнего maintenance task?

Status: implemented для Docker container logs. Панели: log volume by level (семантичные цвета уровней error / warn / info / unknown), errors / warnings / panics, all container logs и textbox-фильтр `search`. Из-за отсутствия per-container labels (см. "Loki label reality") фильтрация текстовая, не по labels. systemd journal collection не настроен.

## Dashboard Standards

### Naming

Dashboard names:

- `00 Overview`
- `10 Infrastructure`
- `15 Applications`
- `20 Backups`
- `30 Services`
- `40 Logs / Operations`

Panel names должны отвечать на operational question, а не только повторять metric name:

- `Disk usage by mount`
- `Backup age by database`
- `Last backup status`
- `Docker build cache reclaimed`
- `Recent backup errors`

### Folder Hierarchy

Grafana folder:

- `The Hub`

Dashboards внутри folder должны сохранять numeric prefixes.

### Default Time Ranges

- Overview: `now-24h to now`
- Infrastructure: `now-24h to now`
- Backups: `now-14d to now`
- Services: `now-24h to now`
- Logs / Operations: `now-24h to now`

### Units

- bytes: `bytes`
- percentages: `percent (0-100)`
- timestamps: Unix seconds rendered as date/time
- durations: `seconds`
- success/failure: `0/1`
- counts: `short`

### Panel Types

- `Stat`: current status, latest successful backup time, backup age, cleanup status.
- `Time series`: CPU, memory, disk trend, backup duration trend, backup size trend.
- `Table`: per-database backup inventory, target status, last run summary.
- `Bar gauge`: disk usage by mount, backup age by database, cache before/after cleanup.
- `Logs`: Loki queries for service execution history and errors.

### Label And Cardinality Rules

Stable Prometheus labels:

- `job`
- `instance`
- `host`
- `service`
- `database`
- `system`
- `backup_type`
- `source_kind`

Stable Loki labels:

- `job`
- `service`
- `host`

Note: это target-состояние. Фактически (2026-07-25) Alloy пишет только `service_name="unknown_service"` + `detected_level`; см. "Loki label reality".

Do not use high-cardinality values as labels:

- filenames;
- byte sizes;
- timestamps;
- error messages;
- backup paths;
- request IDs.

Keep these values inside log messages or metric samples, not labels.

### Version Control And Provisioning

Dashboard definitions should be stored in Git before production use.

Preferred future layout:

```text
monitoring/config/grafana/provisioning/datasources/
monitoring/config/grafana/provisioning/dashboards/
monitoring/config/grafana/dashboards/
```

Provisioning strategy:

- datasource provisioning for Prometheus and Loki;
- dashboard provisioning from JSON files;
- one dashboard JSON per documented dashboard;
- dashboard changes reviewed in Git;
- formulas and query intent kept in this document.

## Metric Catalog

Status values:

- `available`: current repository config can produce this data.
- `implemented`: metric exists and is visualized on a dashboard panel.
- `planned`: target panel is part of dashboard architecture, but implementation is not complete.
- `instrumentation required`: component changes are required before metric exists.

| Dashboard | Panel / Metric | Operational question | Source service | Datasource | Raw metric / log source | Formula / PromQL / LogQL | Unit | Status |
|---|---|---|---|---|---|---|---|---|
| 00 Overview | Backup status summary | Есть ли failed или stale backups? | backup scripts | Prometheus | `backup_last_success_timestamp_seconds`, `backup_last_run_success` | `time() - backup_last_success_timestamp_seconds`; latest `backup_last_run_success` by `backup_type`, `database`, `system` | seconds, 0/1 | instrumentation required |
| 00 Overview | Infrastructure health summary | Есть ли disk/memory/CPU pressure? | node-exporter | Prometheus | node filesystem, memory, CPU metrics | see Infrastructure formulas below | percent | available |
| 00 Overview | Monitoring target health | Все ли scrape targets доступны? | Prometheus | Prometheus | `up` | `up{job=~"prometheus|node-exporter|cadvisor"}` | 0/1 | available |
| 00 Overview | Recent operational errors | Есть ли свежие errors в logs? | Alloy / Loki | Loki | Docker container logs now; systemd logs planned | `{job=~".+"} |= "ERROR"`; final labels depend on Alloy pipeline | logs | partially available |
| 10 Infrastructure | Disk usage by mount | Какие filesystems близки к заполнению? | node-exporter | Prometheus | `node_filesystem_size_bytes`, `node_filesystem_avail_bytes` | `100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"})` | percent | available |
| 10 Infrastructure | Memory usage | Есть ли memory pressure? | node-exporter | Prometheus | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` | percent | available |
| 10 Infrastructure | CPU usage | Есть ли sustained CPU pressure? | node-exporter | Prometheus | `node_cpu_seconds_total` | `100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))` | percent | available |
| 10 Infrastructure | Filesystem free bytes | Сколько disk space осталось? | node-exporter | Prometheus | `node_filesystem_avail_bytes` | `node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}` | bytes | available |
| 10 Infrastructure | Prometheus scrape health | Какие monitoring targets down? | Prometheus | Prometheus | `up` | `up` | 0/1 | available |
| 10 Infrastructure | Container CPU usage | Какие containers потребляют CPU? | cadvisor | Prometheus | cAdvisor container CPU metrics | `sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[5m]))` | cores | available |
| 10 Infrastructure | Container memory usage | Какие containers потребляют memory? | cadvisor | Prometheus | cAdvisor container memory metrics | `container_memory_working_set_bytes{name!=""}` | bytes | available |
| 20 Backups | Last successful backup timestamp | Когда был последний successful backup? | `backup-postgres.sh`, `backup-sqlite.sh` | Prometheus | planned textfile metric `backup_last_success_timestamp_seconds` | `backup_last_success_timestamp_seconds{backup_type=~"postgres|sqlite"}` | Unix seconds | instrumentation required |
| 20 Backups | Backup age | Насколько старый последний successful backup? | backup scripts | Prometheus | `backup_last_success_timestamp_seconds` | `time() - backup_last_success_timestamp_seconds` | seconds | instrumentation required |
| 20 Backups | Backup success/failure | Последний запуск был successful? | backup scripts | Prometheus | `backup_last_run_success` | `backup_last_run_success{backup_type=~"postgres|sqlite"}` | 0/1 | instrumentation required |
| 20 Backups | Backup size | Как меняется размер backup? | backup scripts | Prometheus | `backup_size_bytes` | `backup_size_bytes{backup_type=~"postgres|sqlite"}` | bytes | instrumentation required |
| 20 Backups | Backup duration | Сколько длится backup? | backup scripts | Prometheus | `backup_duration_seconds` | `backup_duration_seconds{backup_type=~"postgres|sqlite"}` | seconds | instrumentation required |
| 20 Backups | Backup by database/system | Какие databases покрыты backup monitoring? | backup scripts | Prometheus | labels on backup metrics | group by `backup_type`, `database`, `system` | table | instrumentation required |
| 20 Backups | PostgreSQL backup logs | Что произошло в PostgreSQL backup job? | `the-hub-postgres-backup.service` | Loki | systemd journal | `{job="systemd", service="the-hub-postgres-backup"} ` | logs | instrumentation required |
| 20 Backups | SQLite backup logs | Что произошло в SQLite backup job? | `the-hub-sqlite-backup.service` | Loki | systemd journal | `{job="systemd", service="the-hub-sqlite-backup"} ` | logs | instrumentation required |
| 20 Backups | Backup heartbeat | Последний push monitor получил heartbeat? | Uptime Kuma | Uptime Kuma / Grafana optional | PostgreSQL and SQLite Push monitors | not primary metric source; optional visual link only | status | planned |
| 30 Services | Service availability | Доступны ли public services? | Uptime Kuma | Uptime Kuma | monitors for Finpipe, Grafana, VPS, internal services | Uptime Kuma UI / optional datasource if added later | status | planned |
| 30 Services | Finpipe application metrics | Есть ли app-level latency/errors? | Finpipe | Prometheus | no metrics in repo | service instrumentation required | varies | instrumentation required |
| 30 Services | Yo Registry application metrics | Есть ли app-level latency/errors? | Yo Registry | Prometheus | no metrics in repo | service instrumentation required | varies | instrumentation required |
| 30 Services | Traect application metrics | Есть ли app-level latency/errors? | Traect | Prometheus | no metrics in repo | service instrumentation required | varies | instrumentation required |
| 30 Services | Echo application metrics | Есть ли app-level latency/errors? | Echo | Prometheus | no metrics in repo | service instrumentation required | varies | instrumentation required |
| 40 Logs / Operations | Container logs | Что пишут containers? | Alloy Docker source | Loki | Docker container stdout/stderr | query by stable container/job labels from Alloy discovery | logs | available |
| 40 Logs / Operations | Systemd errors | Какие systemd units пишут errors? | Alloy journal source | Loki | systemd journal | `{job="systemd"} |= "ERROR"` with labels `service`, `host` | logs | instrumentation required |
| 40 Logs / Operations | PostgreSQL backup errors | Почему PostgreSQL backup failed? | systemd journal | Loki | `the-hub-postgres-backup.service` stdout/stderr | `{job="systemd", service="the-hub-postgres-backup"} |= "ERROR"` | logs | instrumentation required |
| 40 Logs / Operations | SQLite backup errors | Почему SQLite backup failed? | systemd journal | Loki | `the-hub-sqlite-backup.service` stdout/stderr | `{job="systemd", service="the-hub-sqlite-backup"} |= "ERROR"` | logs | instrumentation required |
| 40 Logs / Operations | Docker cache cleanup logs | Что произошло во время cleanup? | `the-hub-docker-build-cache-cleanup.service` | Loki | systemd journal | `{job="docker-cache-cleanup", service="the-hub-docker-build-cache-cleanup"}` | logs | instrumentation required |
| 40 Logs / Operations | Docker cache cleanup errors | Были ли cleanup errors? | `the-hub-docker-build-cache-cleanup.service` | Loki | systemd journal | `{job="docker-cache-cleanup", service="the-hub-docker-build-cache-cleanup"} |= "ERROR"` | logs | instrumentation required |
| 40 Logs / Operations | Latest successful Docker cache cleanup | Когда cleanup последний раз успешно завершился? | Docker cache cleanup script | Prometheus | `docker_build_cache_last_success_timestamp_seconds` | `time() - docker_build_cache_last_success_timestamp_seconds` | seconds | available |
| 10 Infrastructure | Docker build cache before cleanup | Сколько cache было до cleanup? | Docker cache cleanup script | Prometheus | `docker_build_cache_before_bytes` | `docker_build_cache_before_bytes` | bytes (IEC) | implemented |
| 10 Infrastructure | Docker build cache after cleanup | Сколько cache осталось после cleanup? | Docker cache cleanup script | Prometheus | `docker_build_cache_after_bytes` | `docker_build_cache_after_bytes` | bytes (IEC) | implemented |
| 10 Infrastructure | Docker build cache reclaimed | Сколько места освободили? (`0` = valid) | Docker cache cleanup script | Prometheus | `docker_build_cache_reclaimed_bytes` | `docker_build_cache_reclaimed_bytes` | bytes (IEC) | implemented |
| 10 Infrastructure | Docker build cache cleanup status | Последний cleanup успешен? | Docker cache cleanup script | Prometheus | `docker_build_cache_prune_success` | `docker_build_cache_prune_success`; `1` = Success, `0` = Failed | 0/1 | implemented |
| 10 Infrastructure | Docker build cache last successful cleanup age | Насколько давно был успешный cleanup? | Docker cache cleanup script | Prometheus | `docker_build_cache_last_success_timestamp_seconds` | `time() - docker_build_cache_last_success_timestamp_seconds` | seconds (duration) | implemented |
| 10 Infrastructure | Docker build cache cleanup duration | Сколько длился последний cleanup? | Docker cache cleanup script | Prometheus | `docker_build_cache_cleanup_duration_seconds` | `docker_build_cache_cleanup_duration_seconds` | seconds | implemented |

> Примечание: numeric Docker build cache метрики документированы в архитектуре под `20 Backups`, но этот дашборд ещё не создан (backup instrumentation отсутствует). Панели реализованы в существующем `10 Infrastructure` (категория Infrastructure / maintenance), чтобы не плодить ad-hoc дашборд. Метрика `docker_build_cache_last_run_timestamp_seconds` также экспортируется, но на панель не выведена (для возраста используется `..._last_success_timestamp_seconds`).

## Backup Metrics Contract

Unified backup scripts должны экспортировать numeric metrics через Prometheus. Preferred transport: `node_exporter` textfile collector, если он будет включён в текущую monitoring architecture.

Required labels:

- `backup_type`: `postgres` или `sqlite`
- `database`: database/output name, например `finpipe`, `registry`, `grafana`
- `system`: human-readable system, например `Finpipe`, `Yo Registry`, `Grafana`
- `source_kind`: для SQLite `host_path` или `docker_cp`; для PostgreSQL можно использовать `docker_exec`
- `host`: hostname

Required metrics:

```text
backup_last_success_timestamp_seconds{backup_type,database,system,source_kind,host}
backup_last_run_timestamp_seconds{backup_type,database,system,source_kind,host}
backup_last_run_success{backup_type,database,system,source_kind,host}
backup_size_bytes{backup_type,database,system,source_kind,host}
backup_duration_seconds{backup_type,database,system,source_kind,host}
```

Backup age formula:

```promql
time() - backup_last_success_timestamp_seconds
```

Current status: instrumentation required. Existing scripts currently log to stdout/stderr and push to Uptime Kuma, but do not write Prometheus metrics.

## Docker Build Cache Cleanup

Feature: Automatic Docker build cache cleanup with Grafana metrics.

Status: implemented. Metrics are exported through `node_exporter` textfile collector.

Process:

1. Run twice per month.
2. Measure Docker build cache before cleanup.
3. Run `docker builder prune -af`.
4. Measure Docker build cache after cleanup.
5. Export metrics to Prometheus.
6. Log cleanup to journald and Loki.

Metric transport: `node_exporter` textfile collector.

Planned metrics:

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
docker_build_cache_reclaimed_bytes
  = max(docker_build_cache_before_bytes
        - docker_build_cache_after_bytes, 0)
```

Last cleanup age:

```promql
time() - docker_build_cache_last_run_timestamp_seconds
```

Last successful cleanup age:

```promql
time() - docker_build_cache_last_success_timestamp_seconds
```

Implemented Grafana panels:

Расположение: dashboard `10 Infrastructure` (uid `the-hub-10-infra`), row `Docker build cache cleanup`. Datasource: Prometheus (`afpxbacgo8tmod`). Все targets — instant queries, без дополнительных labels.

- Bar gauge `Docker build cache (before / after / reclaimed)` — `docker_build_cache_before_bytes`, `docker_build_cache_after_bytes`, `docker_build_cache_reclaimed_bytes`, unit `bytes` (IEC). Нейтральный цвет: `reclaimed = 0` не помечается как ошибка.
- Stat `Last cleanup status` — `docker_build_cache_prune_success`, value mapping `1` = Success (green) / `0` = Failed (red).
- Stat `Last successful cleanup age` — `time() - docker_build_cache_last_success_timestamp_seconds`, unit `dtdurations`.
- Stat `Cleanup duration` — `docker_build_cache_cleanup_duration_seconds`, unit `s`.

Stale threshold (для `Last successful cleanup age`):

Cleanup выполняется 1-го и 15-го числа каждого месяца. Максимальный нормальный интервал между запусками — с 15-го по 1-е следующего месяца, до ~17 дней. Поэтому короткий порог давал бы ложные срабатывания. Пороги:

- green: `< 18 days` (`1555200 s`) — норма;
- yellow: `>= 18 days` — запуск, возможно, задержан;
- red: `>= 21 days` (`1814400 s`) — плановый запуск явно пропущен.

Required Loki logs:

- all cleanup logs;
- ERROR logs only;
- latest successful cleanup context.

Stable Loki labels:

- `job="docker-cache-cleanup"`
- `service="the-hub-docker-build-cache-cleanup"`
- `host=<current hostname>`

Do not use cache sizes, timestamps or error messages as Loki labels.

## Loki Query Guidelines

Current Alloy config reads Docker container logs only. Systemd journal queries below require adding an Alloy journal source.

Conceptual queries:

```logql
{job="systemd", service="the-hub-postgres-backup"}
{job="systemd", service="the-hub-postgres-backup"} |= "ERROR"

{job="systemd", service="the-hub-sqlite-backup"}
{job="systemd", service="the-hub-sqlite-backup"} |= "ERROR"

{job="docker-cache-cleanup", service="the-hub-docker-build-cache-cleanup"}
{job="docker-cache-cleanup", service="the-hub-docker-build-cache-cleanup"} |= "ERROR"

{job="systemd"} |= "ERROR"
```

Labels must remain stable:

- `job`
- `service`
- `host`

Messages should contain human-readable details such as filenames, sizes, durations and errors.

## Available Metrics Now

Available through current Prometheus config:

- `up` for `prometheus`, `node-exporter`, `cadvisor`.
- `node_filesystem_size_bytes`
- `node_filesystem_avail_bytes`
- `node_memory_MemTotal_bytes`
- `node_memory_MemAvailable_bytes`
- `node_cpu_seconds_total`
- cAdvisor container metrics, including common container CPU and memory series such as `container_cpu_usage_seconds_total` and `container_memory_working_set_bytes`.

Available logs now:

- Docker container stdout/stderr through Alloy Docker source into Loki.

Available heartbeat now:

- backup Push monitors through Uptime Kuma, configured by local files in `/etc/the-hub-backup/`.

## Metrics Requiring Instrumentation

- `backup_last_success_timestamp_seconds`
- `backup_last_run_timestamp_seconds`
- `backup_last_run_success`
- `backup_size_bytes`
- `backup_duration_seconds`
- service-specific application metrics for `Finpipe`, `Yo Registry`, `Traect`, `Echo`.

## Discrepancies Found

- `monitoring/compose.yaml` includes `cadvisor`, while `docker/monitoring.compose.yml` does not.
- `monitoring/compose.yaml` uses explicit `monitoring` and `finpipe-shared` networks; `docker/monitoring.compose.yml` does not.
- `monitoring/config/prometheus/prometheus.yml` scrape'ит `cadvisor`; `docker/prometheus.yml` does not.
- `monitoring/compose.yaml` mounts repository-owned Loki config with 30-day retention; `docker/monitoring.compose.yml` still uses the Loki image-bundled config and is treated as legacy.
- Grafana dashboards созданы live в Grafana (folder `The Hub`), но provisioning files и dashboard JSON пока не сохранены в репозиторий.
- Фактические Loki labels (`service_name="unknown_service"`) не совпадают с target-labels (`job` / `service` / `host`) из этого документа — Alloy pipeline не добавляет container/systemd labels.
- Дашборд `Infra / VPS` удалён, его содержимое перенесено в `10 Infrastructure`.
- Alloy currently collects Docker logs, not systemd journal logs. Backup service LogQL panels require new Alloy journal config.
- Backup scripts send Uptime Kuma Push heartbeats and logs, but do not expose Prometheus metrics.
- `node-exporter` textfile collector is configured for infrastructure-generated `.prom` files in `/var/lib/node_exporter/textfile_collector`.

## Recommended Implementation Order

Done:

- `10 Infrastructure`, `15 Applications`, `40 Logs / Operations` и базовый `00 Overview` реализованы на текущих `node-exporter` / `cadvisor` / Loki метриках.
- Docker build cache cleanup metrics are implemented through `node_exporter` textfile collector.

Next:

1. Add backup metrics export through `node_exporter` textfile collector or another explicit Prometheus-compatible path.
2. Create `20 Backups` Grafana dashboard from this catalog.
3. Добавить container/systemd labels в Alloy pipeline, затем перевести Loki-панели на label-based queries.
4. Extend `00 Overview` backup status summary после появления backup metrics.
5. Add service-specific dashboards only when services expose real metrics.
6. Сохранить dashboard JSON и provisioning files в репозиторий (см. "Version Control And Provisioning").
