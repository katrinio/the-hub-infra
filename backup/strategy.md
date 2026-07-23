# Backup Strategy

Этот документ фиксирует целевую backup architecture для `the-hub-infra`.

## Responsibilities

- Application-managed: `Finpipe`, `Traect`, `Echo`, `Postbox`
- Infrastructure-managed: `Yo Registry`, `Uptime Kuma`, `Grafana`

Application-owned рабочие скрипты не заменяются, если они уже существуют и подтверждены в эксплуатации.

## PostgreSQL

- `Finpipe` резервируется через `pg_dump`.
- `Yo Registry` резервируется через PostgreSQL backup и отдельный filesystem backup.
- PostgreSQL volume не заменяет логический backup.
- `Yo Registry` использует PostgreSQL-инстанс `Finpipe`, но отдельную базу.
- Для PostgreSQL обязательный restore path: `pg_restore`.

## SQLite

- Plain `cp` небезопасен для live SQLite database.
- Для SQLite в `wal` mode это особенно важно, потому что согласованное состояние зависит от основного файла и sidecar-файлов WAL/SHM.
- `sqlite3 .backup` использует SQLite backup API и создаёт согласованный snapshot.
- Все SQLite-системы резервируются через SQLite Backup API.
- Для infrastructure-managed SQLite backup используются `Uptime Kuma` и `Grafana`.
- `Traect`, `Echo` и `Postbox` остаются application-managed.
- `Uptime Kuma` использует `wal` mode и поэтому должен резервироваться только безопасным snapshot-методом.
- `Grafana` находится внутри Docker volume и требует чтения с root-level доступом.
- `Postbox` остаётся inactive до фактического deployment production DB.

## Filesystem Backup Policy

- Резервируются только невосстановимые файлы.
- Временные uploads не резервируются.
- Данные, полностью содержащиеся в PostgreSQL, отдельно не резервируются.
- Файловые копии, являющиеся рабочим кэшем, не резервируются.
- `Finpipe` filesystem backup не требует, потому что все критичные данные находятся в PostgreSQL.
- Encrypted signatures в `Finpipe` резервируются как данные PostgreSQL, а не как filesystem files.
- `Yo Registry` processed images являются authoritative filesystem data.
- `Yo Registry` authoritative filesystem path: `/srv/data/yo-registry/uploads`.
- `Portainer` будет добавлен после внедрения.

## Backup Layout

Рекомендуемая локальная структура:

```text
/srv/backups/<timestamp>/
├── postgres/
├── sqlite/
└── manifest.txt
```

Filesystem локально в staging не копируется.
`restic` должен архивировать staging directory и `/srv/data/yo-registry/uploads`.

## Orchestration

Будущий `backup-all` pipeline должен выполнять:

1. Создать staging directory.
2. Выполнить PostgreSQL backup.
3. Выполнить SQLite backup.
4. Проверить успешность.
5. Остановить `Registry`.
6. Запустить `restic` для:
   - staging directory
   - `/srv/data/yo-registry/uploads`
7. Запустить `Registry`.
8. Выполнить retention.
9. Записать `manifest.txt`.
10. Завершиться ошибкой при любой неудаче.

Если сервис был остановлен для backup-пайплайна, он должен быть запущен обратно даже при ошибке.

## Exclusions

- `Prometheus TSDB` и `Loki data` по-прежнему исключены из обязательных backup-задач.
- Их история считается восстанавливаемой или некритичной, пока не появятся требования по долгосрочному хранению или аудиту.

## Principles Reference

Обязательные правила backup и restore собраны в [principles.md](principles.md).
