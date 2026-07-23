# Backup Inventory

Этот документ описывает, какие данные резервируются и каким способом они управляются.

## PostgreSQL

| Crit | System | Component | Database | Location | Backup Method | Source | Format | Notes |
|---|---|---|---|---|---|---|---|---|
| 🔴 | Finpipe | PostgreSQL | `finpipe` | `finpipe-postgres-1 / finpipe` | application-managed Python workflow | `/home/katrin/projects/finpipe/src/workflows/monitoring/backup_database.py` | plain SQL compressed as `.sql.gz` | Не управляется `backup/scripts/backup-postgres.sh` |
| 🔴 | Yo Registry | PostgreSQL | `registry` | `finpipe-postgres-1 / registry` | infrastructure-managed `backup-postgres.sh` | `backup/scripts/backup-postgres.sh` | `pg_dump` custom `.dump` | Использует PostgreSQL-инстанс Finpipe, но отдельную базу |

## SQLite

| Crit | System | Component | Location | Backup Method | Schedule | Retention | Notes |
|---|---|---|---|---|---|---|---|
| 🟡 | Traect | SQLite | `/home/katrin/projects/traect/data/traect.db` | application-managed `sqlite3 .backup` | daily `05:30` via user crontab | `30 days` | `Journal mode: delete`. Existing script: `/home/katrin/projects/traect/backup.sh` |
| 🟡 | Echo | SQLite | `/home/katrin/data/echo/echo.db` | application-managed `sqlite3 .backup` | daily `05:15` via user crontab | `30 days` | Existing script: `/home/katrin/scripts/echo/backup.sh`. Hardcoded monitoring URL is technical debt and must not be copied into Git |
| 🟡 | Postbox | SQLite | `/home/katrin/projects/postbox/data/postbox.db` expected path | application-managed `VACUUM INTO` with integrity verification | No active schedule confirmed | TODO | Not yet deployed. Existing scripts: `/home/katrin/projects/postbox/scripts/backup_sqlite.sh` and `/home/katrin/projects/postbox/scripts/verify_backup.sh` |
| 🟡 | Uptime Kuma | SQLite | `/home/katrin/projects/uptime-kuma/data/kuma.db` | infrastructure-managed `backup-sqlite.sh` via `sqlite3 .backup` | Planned via systemd timer | `30 days` | `Journal mode: wal`. Safe SQLite snapshot required. No prior backup found |
| 🟡 | Grafana | SQLite | `/var/lib/docker/volumes/monitoring_grafana-data/_data/grafana.db` | infrastructure-managed `backup-sqlite.sh` via `sqlite3 .backup` | Planned via systemd timer | `30 days` | No prior backup found. Root-level read permission required |

## Filesystem

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Yo Registry | Processed Images | `TBD (deployment path)` | `Filesystem + restic` | preferred | Restore together with DB paths |
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
| TLS certificates | TODO | Manual secure handling | TODO |
| Registry credentials | TODO | Manual secure handling | TODO |
| SSH keys | TODO | Manual secure handling | TODO |

## External Backup Targets

| Target | Location | Status | Notes |
|---|---|---|---|
| PostgreSQL staging directory | `/srv/backups/staging/postgres` | Planned | Используется для инфраструктурного Registry backup |
| SQLite staging directory | `/srv/backups/staging/sqlite` | Planned | Используется для инфраструктурных backup `Uptime Kuma` и `Grafana` |

## Retention Policy

| Type | Keep |
|---|---|
| Registry PostgreSQL dumps | `14 days` |
| Uptime Kuma SQLite dumps | `30 days` |
| Grafana SQLite dumps | `30 days` |
