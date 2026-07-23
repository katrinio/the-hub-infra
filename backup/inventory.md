# Backup Inventory

Этот документ описывает все данные, которые необходимо резервировать,
как они сохраняются и как восстанавливаются.

> Последнее обновление: YYYY-MM-DD

---

|Criticality| Значение                                                       |
|--------|----------------------------------------------------------------|
|🔴 Critical| 	Потеря недопустима (PostgreSQL, Registry, Uploads)            |
|🟡 Important| Потеря нежелательна (Grafana, Uptime Kuma, Portainer)          |
|🟢 Rebuildable|  Можно восстановить из Git (Alloy, Prometheus config, Compose) |

## PostgreSQL

|Crit| System | Database | Location | Backup Method | Stop Service? | Restore Notes |
|--------|--------|----------|----------|---------------|---------------|---------------|
|🔴| Finpipe | | | `pg_dump` | No | |
|🔴| Traect | | | `pg_dump` | No | |
|🔴| Yo Registry | | | `pg_dump` | No | |

---

## SQLite

|Crit| System | Database | Location | Backup Method | Stop Service? | Restore Notes |
|--------|--------|----------|----------|---------------|---------------|---------------|
|🔴| Echo | | | `sqlite3 .backup` | No | |
|🔴| Postbox | | | `sqlite3 .backup` | No | *(ещё не развёрнут окончательно)* |
|🟡| Uptime Kuma | | | `sqlite3 .backup` | No | |
|🟡| Grafana | | | `sqlite3 .backup` | No | |

---

## Filesystem Data

|Crit| System | Data | Location | Backup Method | Stop Service? | Restore Notes |
|--------|--------|------|----------|---------------|---------------|---------------|
|🔴| Finpipe | Uploads | | Filesystem | No | |
|🔴| Yo Registry | Image Storage | | Filesystem | Preferred | |
|🟡| Portainer | Application Data | | Filesystem | No | |

---

## Git Managed

> Эти данные не требуют отдельного резервного копирования, так как являются частью Git-репозиториев.

|Crit| System | Component | Repository |
|--------|--------|-----------|------------|
|🟢| Monitoring | Alloy configuration | `the-hub-infra` |
|🟢| Monitoring | Prometheus configuration | `the-hub-infra` |
|🟢| Monitoring | Docker Compose | `the-hub-infra` |
|🟢| Monitoring | Grafana provisioning | `the-hub-infra` |

---

## Secrets

| Item | Location | Included in Backup | Notes |
|------|----------|-------------------|-------|
| `.env` files | | Yes | |
| SSH keys | | No | Stored separately |
| TLS certificates | | | |
| Registry credentials | | | |

---

## External Backup Target

| Repository | Location |
|------------|----------|
| Primary | |
| Secondary | |

---

## Retention Policy

| Type | Keep |
|------|------|
| Daily | |
| Weekly | |
| Monthly | |
| Yearly | |

---

## Restore Checklist

### PostgreSQL

- [ ] Restore global roles (`pg_dumpall --globals-only`)
- [ ] Create database
- [ ] Restore with `pg_restore`
- [ ] Verify application

### SQLite

- [ ] Restore database file
- [ ] Run `PRAGMA integrity_check`
- [ ] Start application
- [ ] Verify application

### Filesystem

- [ ] Restore files/directories
- [ ] Verify ownership and permissions
- [ ] Restart service
- [ ] Verify application

---

## Notes