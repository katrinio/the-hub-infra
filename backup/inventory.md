# Backup Inventory

Этот документ перечисляет данные, которые должны попасть в резервное копирование.
Неизвестные значения помечены как `TODO`.

## PostgreSQL

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Finpipe | PostgreSQL database | TODO | `pg_dump` | No | TODO |
| 🔴 | Traect | PostgreSQL database | TODO | `pg_dump` | No | TODO |
| 🔴 | Yo Registry | PostgreSQL database | TODO | `pg_dump` | No | TODO |

## SQLite

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴  | Echo | SQLite database | TODO | `sqlite3 .backup` | No | TODO |
| 🔴  | Postbox | SQLite database | TODO | `sqlite3 .backup` | No | Сервис находится на VPS, но ещё не развёрнут окончательно. TODO |
| 🟡 | Uptime Kuma | SQLite database | TODO | `sqlite3 .backup` | No | TODO |
| 🟡 | Grafana | SQLite database | TODO | `sqlite3 .backup` | No | TODO |

## Filesystem

| Crit | System | Component | Location | Backup Method | Stop Service? | Restore Notes |
|---|---|---|---|---|---|---|
| 🔴 | Finpipe | Uploads | TODO | restic | preferred | TODO |
| 🔴 | Yo Registry | Image Storage | TODO | restic | preferred | TODO |
| 🟡 | Portainer | Application Data | TODO | restic | preferred | TODO |

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
| Primary restic repository | TODO | TODO | TODO |
| Secondary target | TODO | TODO | TODO |

## Retention Policy

| Type | Keep |
|---|---|
| Daily | TODO |
| Weekly | TODO |
| Monthly | TODO |
| Yearly | TODO |
