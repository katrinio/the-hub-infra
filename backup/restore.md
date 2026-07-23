# Disaster Recovery Runbook

Этот документ описывает восстановление PostgreSQL и SQLite backups.

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

## SQLite

1. Остановить owning application до замены файла базы.
2. Сохранить текущую или повреждённую БД отдельно перед restore.
3. Восстанавливать только из заранее проверенного backup-файла.
4. Сохранить ownership и permissions после замены файла.
5. Выполнить `PRAGMA integrity_check;`.
6. Перезапустить приложение.
7. Проверить health.

## Uptime Kuma

1. Остановить контейнер `Uptime Kuma`.
2. Восстановить БД как `data/kuma.db`.
3. Убедиться, что stale `-wal` и `-shm` side files не остаются перед стартом.
4. Сохранить корректные permissions.
5. Запустить контейнер и проверить monitors.

## Grafana

1. Остановить `Grafana`.
2. Восстановить `grafana.db` в Docker volume.
3. Вернуть ownership к `uid 472` и ожидаемые group/mode.
4. Запустить `Grafana`.
5. Проверить dashboards, users и alerting.

## Traect And Echo

- `Traect` использует application-managed backup в `/home/katrin/projects/traect/backup.sh`.
- `Echo` использует application-managed backup в `/home/katrin/scripts/echo/backup.sh`.

## Postbox

- Restore для `Postbox` документируется только после фактического deployment production DB.
