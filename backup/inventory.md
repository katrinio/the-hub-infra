# Backup Inventory

Этот документ описывает, какие данные резервируются и каким способом они управляются.

## PostgreSQL

| Crit | System | Component | Database | Location | Backup Method | Source | Format | Notes |
|---|---|---|---|---|---|---|---|---|
| 🔴 | Finpipe | PostgreSQL | `finpipe` | `finpipe-postgres-1 / finpipe` | application-managed Python workflow | `/home/katrin/projects/finpipe/src/workflows/monitoring/backup_database.py` | plain SQL compressed as `.sql.gz` | Не управляется `backup/scripts/backup-postgres.sh` |
| 🔴 | Yo Registry | PostgreSQL | `registry` | `finpipe-postgres-1 / registry` | infrastructure-managed `backup-postgres.sh` | `backup/scripts/backup-postgres.sh` | `pg_dump` custom `.dump` | Использует PostgreSQL-инстанс Finpipe, но отдельную базу |

## SQLite

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Traect | SQLite | `/data/traect.db` inside the application container/volume | `sqlite3 .backup` | No | Не относится к PostgreSQL |
| 🔴 | Echo | SQLite database | TODO | `sqlite3 .backup` | No | TODO |
| 🔴 | Postbox | SQLite database | TODO | `sqlite3 .backup` | No | Сервис находится на VPS, но ещё не развёрнут окончательно. TODO |
| 🟡 | Uptime Kuma | SQLite database | TODO | `sqlite3 .backup` | No | TODO |
| 🟡 | Grafana | SQLite database | TODO | `sqlite3 .backup` | No | TODO |

## Filesystem

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Finpipe | Uploads | TODO | TODO | preferred | TODO |
| 🔴 | Yo Registry | Image Storage | TODO | TODO | preferred | TODO |
| 🟡 | Portainer | Application Data | TODO | TODO | preferred | TODO |

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

## Retention Policy

| Type | Keep |
|---|---|
| Registry PostgreSQL dumps | `14 days` | 
