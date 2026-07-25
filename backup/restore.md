# Disaster Recovery Runbook

Этот документ описывает восстановление PostgreSQL, SQLite и filesystem data.

## Restore Principles

- Для PostgreSQL используется `pg_restore`.
- Для SQLite выполняется замена database file и `PRAGMA integrity_check;`.
- Для filesystem сначала восстанавливаются файлы, затем database, затем проверяется совпадение путей.
- Filesystem и database должны восстанавливаться согласованно.

## Yo Registry

Формат backup: custom PostgreSQL dump `.dump`.

1. Остановить Registry.
2. Создать или очистить целевую базу `registry`.
3. Выполнить `pg_restore` в целевую базу.
4. Проверить owner и privileges.
5. Запустить Registry.
6. Проверить health.

## Finpipe

Формат backup: PostgreSQL logical backup.

1. Остановить Finpipe или перевести его в безопасный режим восстановления.
2. Восстановить дамп через `pg_restore`.
3. Проверить схему, данные и доступ приложения.
4. Убедиться, что критичные секреты, включая `SIGNATURE_ENCRYPTION_KEY`, восстановлены отдельно.

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
2. Восстановить `grafana.db` в контейнерный path `/var/lib/grafana/grafana.db`.
3. Вернуть ownership к `uid 472` и ожидаемые group/mode.
4. Запустить `Grafana`.
5. Проверить dashboards, users и alerting.

## Filesystem Restore

Filesystem и database должны восстанавливаться согласованно.

## Yo Registry Filesystem

1. Остановить приложение.
2. Восстановить filesystem.
3. Восстановить PostgreSQL.
4. Убедиться, что `photo_processed_path` соответствует существующим файлам.
5. Проверить права.
6. Запустить приложение.

## Traect And Echo

- `Traect` и `Echo` переходят на unified infrastructure-managed SQLite backup.
- Существующие application-managed backup scripts пока не удаляются до проверки новой схемы на production VPS.

## Postbox

- Restore для `Postbox` документируется только после фактического deployment production DB.
