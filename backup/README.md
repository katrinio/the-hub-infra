# Backup

Каталог `backup/` содержит документацию, шаблоны конфигурации, shell-скрипты и шаблоны systemd units
для PostgreSQL backup в `the-hub-infra`.

Реальные скрипты находятся в `backup/scripts/`.
Реальные конфиги должны находиться в `/etc/the-hub-backup/`.

## Архитектура

Текущий фокус:

`logical PostgreSQL dumps -> /srv/backups/staging/postgres -> verification`

Старый `/opt/backups/registry_backup.sh` пока не удалять. Отключать старый Registry backup можно
только после проверки новой схемы.

## Документы

- [inventory.md](inventory.md)
- [strategy.md](strategy.md)
- [restore.md](restore.md)

## Важное предупреждение

Наличие файла бэкапа не считается доказанным backup-процессом без тестовой проверки и рабочего
restore-сценария.

## Staging

Ожидаемое место для staging dumps:

```text
/srv/backups/staging/postgres
```

## Migration Checklist

1. Создать `/etc/the-hub-backup/backup.env`.
2. Создать `/etc/the-hub-backup/postgres.conf`.
3. Выполнить `DRY_RUN=1`.
4. Выполнить один ручной Registry backup.
5. Проверить файл через `pg_restore --list`.
6. Установить systemd units.
7. Дождаться успешного автоматического запуска.
8. Только после этого отключить старый scheduler.
9. Старый скрипт удалить позже отдельным действием.
