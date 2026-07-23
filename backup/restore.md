# Disaster Recovery Runbook

Этот документ описывает восстановление PostgreSQL backups для Finpipe и Yo Registry.

## Yo Registry

Формат backup: custom PostgreSQL dump `.dump`.

1. Остановить Registry.
2. Создать или очистить целевую базу `registry`.
3. Выполнить `pg_restore` в целевую базу.
4. Проверить owner и privileges.
5. Запустить Registry.
6. Проверить health.

## Finpipe

Формат backup: plain SQL compressed as `.sql.gz`.

1. Остановить Finpipe или перевести его в безопасный режим восстановления.
2. Распаковать gzip.
3. Восстановить дамп через `psql`.
4. Не использовать `pg_restore` для plain SQL.
5. Проверить схему, данные и доступ приложения.

## Общие замечания

- Registry и Finpipe используют один PostgreSQL-инстанс, но разные базы.
- Логический backup обязателен даже при наличии Docker volume.
- Все потенциально destructive-действия должны выполняться вручную и с подтверждением оператора.
