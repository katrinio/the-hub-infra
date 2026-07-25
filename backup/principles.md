# Backup Principles

Этот документ фиксирует обязательные правила backup architecture для `the-hub-infra`.

## Backup Principles

1. Backup включает только authoritative data.
2. Generated files не резервируются.
3. Cache не резервируется.
4. Working copies не резервируются.
5. Filesystem резервируется только если он является источником истины.
6. PostgreSQL всегда резервируется через `pg_dump`.
7. PostgreSQL volume никогда не копируется как backup-источник.
8. SQLite всегда резервируется через SQLite Backup API.
9. `cp` живой SQLite database никогда не используется.
10. Каждый backup должен быть пригоден для полного восстановления.

## Restore Principles

- Для PostgreSQL используется `pg_restore`.
- Для SQLite выполняется замена database file, затем `PRAGMA integrity_check;`.
- Для Filesystem сначала восстанавливаются файлы, затем database, после чего проверяется совпадение путей и содержимого.
- Filesystem и database должны восстанавливаться согласованно.

## Critical Secrets

Критичные секреты резервируются отдельно от application data:

- `.env`
- encryption keys
- API keys
- SMTP credentials
- OAuth credentials
- Restic credentials

`SIGNATURE_ENCRYPTION_KEY` является обязательным критичным секретом. Без него PostgreSQL backup
`Finpipe` неполноценен.

## Recommended Retention

- Daily: `7`
- Weekly: `4`
- Monthly: `6`

## Recommended Backup Layout

Локальный staging layout:

```text
/srv/backups/<timestamp>/
├── postgres/
├── sqlite/
└── manifest.txt
```

Filesystem локально в staging не копируется.
Filesystem для `Yo Registry` читается `restic` напрямую.

`restic` должен архивировать:

- staging directory
- `/srv/data/yo-registry/uploads`

## Future Orchestration

Будущий `backup-all` pipeline должен выполнять:

1. Создать staging directory.
2. Выполнить PostgreSQL backup.
3. Выполнить SQLite backup.
4. Проверить успешность промежуточных шагов.
5. Остановить `Registry`.
6. Запустить `restic` для источников:
   - staging directory
   - `/srv/data/yo-registry/uploads`
7. Запустить `Registry`.
8. Выполнить retention.
9. Записать `manifest.txt`.
10. Завершиться ошибкой при любой неудаче.

Если сервис был остановлен для backup-пайплайна, он должен быть запущен обратно даже при ошибке.
