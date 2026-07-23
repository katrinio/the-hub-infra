# Backup

Каталог `backup/` содержит документацию, шаблоны конфигурации, shell-скрипты и шаблоны systemd units
для backup-процессов в `the-hub-infra`.

Реальные скрипты находятся в `backup/scripts/`.
Реальные конфиги должны находиться в `/etc/the-hub-backup/`.

## Архитектура

Текущая схема:

- PostgreSQL dumps: `/srv/backups/staging/postgres`
- SQLite dumps: `/srv/backups/staging/sqlite`

Инфраструктурные скрипты управляют только:

- PostgreSQL: `Yo Registry`
- SQLite: `Uptime Kuma`, `Grafana`

Существующие application-managed backup-скрипты остаются на месте и не заменяются:

- `Traect`
- `Echo`
- `Postbox`
- `Finpipe`

Старый `/opt/backups/registry_backup.sh` пока не удалять. Отключать старый Registry backup можно
только после проверки новой схемы.

## Документы

- [inventory.md](inventory.md)
- [principles.md](principles.md)
- [strategy.md](strategy.md)
- [restore.md](restore.md)

## Важное предупреждение

Наличие файла бэкапа не считается доказанным backup-процессом без тестовой проверки и рабочего
restore-сценария.

## Staging

Ожидаемые места для staging dumps:

```text
/srv/backups/staging/postgres
/srv/backups/staging/sqlite
```

## Filesystem Backup Scope

`Finpipe` отсутствует в filesystem backup scope, потому что production использует PostgreSQL, а
filesystem copies encrypted signatures являются recoverable working artifacts. Authoritative storage
for signatures is PostgreSQL.

`Yo Registry` присутствует в filesystem backup scope, потому что processed images являются
authoritative filesystem data, а база хранит пути `photo_original_path` и `photo_processed_path`.
Production filesystem path: `/srv/data/yo-registry/uploads`.

`Portainer` отсутствует в активном filesystem backup scope, потому что он не развёрнут.

## Backup Layout

Рекомендуемый локальный staging layout:

```text
/srv/backups/<timestamp>/
├── postgres/
├── sqlite/
└── manifest.txt
```

Filesystem локально не копируется в staging.
`restic` должен архивировать staging directory и `/srv/data/yo-registry/uploads`.

## Backup Principles

Обязательные правила вынесены в [principles.md](principles.md).
Документ фиксирует:

- что резервируется;
- что не резервируется;
- почему;
- как восстанавливать;
- какие правила обязательны для всех систем.

## Installation Checklist

1. Создать `/etc/the-hub-backup/backup.env`.
2. Создать `/etc/the-hub-backup/postgres.conf`.
3. Создать `/etc/the-hub-backup/sqlite.conf`.
4. Выполнить `DRY_RUN=1`.
5. Выполнить один ручной Registry backup.
6. Выполнить один ручной SQLite backup для `Uptime Kuma` и `Grafana`.
7. Проверить PostgreSQL dump через `pg_restore --list`.
8. Проверить SQLite dump через `sqlite3 backup.db 'PRAGMA integrity_check;'`.
9. Установить systemd units.
10. Дождаться успешного автоматического запуска.
11. Только после этого отключить старые scheduler jobs отдельным действием.
12. Старые скрипты удалить позже отдельным действием.

## DRY_RUN Example

```bash
DRY_RUN=1 BACKUP_ENV_FILE=/etc/the-hub-backup/backup.env \
SQLITE_BACKUP_CONFIG=/etc/the-hub-backup/sqlite.conf \
/home/katrin/projects/the-hub-infra/backup/scripts/backup-sqlite.sh
```

## Manual Verification Example

```bash
/home/katrin/projects/the-hub-infra/backup/scripts/check-sqlite-backup.sh
```

## Operational Note

Сейчас в Registry есть отдельная существующая проблема: crontab вызывает
`/home/katrin/backups/registry_backup.sh`, но такого файла нет.
Фактический скрипт находится по пути `/opt/backups/registry_backup.sh`.
Это уже существующий broken scheduler и требует отдельного ручного исправления.

## Migration Checklist For Registry

1. Создать `/etc/the-hub-backup/backup.env`.
2. Создать `/etc/the-hub-backup/postgres.conf`.
3. Выполнить `DRY_RUN=1`.
4. Выполнить один ручной Registry backup.
5. Проверить файл через `pg_restore --list`.
6. Установить systemd units.
7. Дождаться успешного автоматического запуска.
8. Только после этого отключить старый scheduler.
9. Старый скрипт удалить позже отдельным действием.
