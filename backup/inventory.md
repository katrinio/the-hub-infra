# Backup Inventory

Этот документ описывает все данные, которые необходимо резервировать,
как они сохраняются и как восстанавливаются.

> Последнее обновление: YYYY-MM-DD

---

## PostgreSQL

| System | Database | Location | Backup Method | Stop Service? | Restore Notes |
|--------|----------|----------|---------------|---------------|---------------|
| Finpipe | | | `pg_dump` | No | |
| Traect | | | `pg_dump` | No | |
| Yo Registry | | | `pg_dump` | No | |

---

## SQLite

| System | Database | Location | Backup Method | Stop Service? | Restore Notes |
|--------|----------|----------|---------------|---------------|---------------|
| Echo | | | `sqlite3 .backup` | No | |
| Postbox | | | `sqlite3 .backup` | No | *(ещё не развёрнут окончательно)* |
| Uptime Kuma | | | `sqlite3 .backup` | No | |
| Grafana | | | `sqlite3 .backup` | No | |

---

## Filesystem Data

| System | Data | Location | Backup Method | Stop Service? | Restore Notes |
|--------|------|----------|---------------|---------------|---------------|
| Finpipe | Uploads | | Filesystem | No | |
| Yo Registry | Image Storage | | Filesystem | Preferred | |
| Portainer | Application Data | | Filesystem | No | |

---

## Git Managed

> Эти данные не резервируются отдельно, так как являются частью Git-репозиториев.

| System | Data | Repository |
|--------|------|------------|
| Alloy | Configuration | `the-hub-infra` |
| Prometheus | Configuration | `the-hub-infra` |
| Monitoring Compose | Compose files | `the-hub-infra` |
| Grafana Provisioning | Configuration | `the-hub-infra` |

---

## Secrets

| Item | Location | Included in Backup | Notes |
|------|----------|-------------------|-------|
| `.env` files | | Yes | |
| SSH keys | | No | Хранятся отдельно |
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

- [ ] Restore roles (`pg_dumpall --globals-only`)
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

```