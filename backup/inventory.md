# Backup Inventory

Этот документ описывает, какие данные резервируются и каким способом они управляются.

## PostgreSQL

| Crit | System | Component | Database | Location | Backup Method | Restore Method | Notes |
|---|---|---|---|---|---|---|---|
| 🔴 | Finpipe | PostgreSQL | `finpipe` | `finpipe-postgres-1 / finpipe` | `pg_dump` | `pg_restore` | Все критичные данные находятся в PostgreSQL. Filesystem backup не требуется |
| 🔴 | Yo Registry | PostgreSQL | `registry` | `finpipe-postgres-1 / registry` | `pg_dump` | `pg_restore` | Использует PostgreSQL-инстанс Finpipe, но отдельную базу |

## SQLite

| Crit | System | Component | Location | Backup Method | Schedule | Retention | Notes |
|---|---|---|---|---|---|---|---|
| 🟡 | Traect | SQLite | `host_path:/home/katrin/projects/traect/data/traect.db` | SQLite Backup API | Planned unified backup | `30 days` | Infrastructure-managed target. Existing application backup and cron stay in place until unified backup is validated |
| 🟡 | Echo | SQLite | `host_path:/home/katrin/data/echo/echo.db` | SQLite Backup API | Planned unified backup | `30 days` | Infrastructure-managed target. Existing application backup and cron stay in place until unified backup is validated |
| 🟡 | Postbox | SQLite | `/home/katrin/projects/postbox/data/postbox.db` expected path | SQLite Backup API | No active schedule confirmed | TODO | Application-managed. Not yet deployed |
| 🟡 | Uptime Kuma | SQLite | `host_path:/home/katrin/projects/uptime-kuma/data/kuma.db` | SQLite Backup API | Planned | `30 days` | Infrastructure-managed. `Journal mode: wal`. Live database is never copied with `cp` |
| 🟡 | Grafana | SQLite | `docker_cp:grafana:/var/lib/grafana/grafana.db` | Container file copy + integrity check | Planned | `30 days` | Infrastructure-managed. Backup user reads the DB through `docker cp` because direct volume access is not safe for the host user |

## Filesystem

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Yo Registry | Processed Images | `/srv/data/yo-registry/uploads` | `Filesystem + restic` | preferred | Restore together with DB paths |
| 🟢 | Portainer | Application Data | `Not deployed` | `Pending` | n/a | Add after deployment |

Finpipe не включается в filesystem backup.
Filesystem copies of encrypted signatures are recoverable working artifacts.
Authoritative storage is PostgreSQL.

`SIGNATURE_ENCRYPTION_KEY` является критичным секретом и должен резервироваться отдельно вместе с
остальными секретами проекта.

Примечание: `Prometheus TSDB` и `Loki data` не включаются в обязательные бэкапы. Их история считается
восстанавливаемой или некритичной, пока не появятся требования по долгосрочному хранению или аудиту.

## Git Managed

| Component | Source | Notes |
|---|---|---|
| Alloy configuration | Git | `TODO` |
| Prometheus configuration | Git | `TODO` |
| Monitoring Docker Compose | Git | `TODO` |
| Grafana provisioning | Git | `TODO` |

## Secrets

| Item | Location | Backup Method | Notes |
|---|---|---|---|
| Environment files | TODO | Manual secure handling | Не хранить в Git |
| `SIGNATURE_ENCRYPTION_KEY` | TODO | Manual secure handling | Без него PostgreSQL backup `Finpipe` неполноценен |
| Encryption keys | TODO | Manual secure handling | Critical secrets |
| API keys | TODO | Manual secure handling | Critical secrets |
| SMTP credentials | TODO | Manual secure handling | Critical secrets |
| OAuth credentials | TODO | Manual secure handling | Critical secrets |
| Restic credentials | TODO | Manual secure handling | Critical secrets |
| TLS certificates | TODO | Manual secure handling | TODO |
| Registry credentials | TODO | Manual secure handling | TODO |
| SSH keys | TODO | Manual secure handling | TODO |

## External Backup Targets

| Target | Location | Status | Notes |
|---|---|---|---|
| Staging directory | `/srv/backups/<timestamp>/` | Recommended | Contains `postgres/`, `sqlite/` and `manifest.txt` |
| Registry filesystem source | `/srv/data/yo-registry/uploads` | Confirmed | Authoritative filesystem data archived by `restic` directly |

## Retention Policy

| Type | Keep |
|---|---|
| Daily | `7` |
| Weekly | `4` |
| Monthly | `6` |
