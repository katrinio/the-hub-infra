# Backup Strategy

Этот документ фиксирует текущие решения по PostgreSQL backup в `the-hub-infra`.

## Decisions

- Finpipe backup остаётся application-managed.
- Registry backup становится infrastructure-managed.
- Сейчас допустимы два формата backup без принудительной унификации:
- Finpipe: `.sql.gz`
- Registry: custom `.dump`
- Не пытаться унифицировать форматы без отдельной миграции.
- PostgreSQL volume не заменяет логический backup.
- Registry использует PostgreSQL-инстанс Finpipe, но отдельную базу.
- Для Registry используется `pg_dump -Fc` через `docker exec` и stdout без `docker cp`.
- Проверка свежести и базовой читаемости dump выполняется отдельно скриптом проверки.

## Scope

- `backup/scripts/backup-postgres.sh` отвечает только за infrastructure-managed PostgreSQL backup.
- Finpipe application workflow остаётся отдельным источником истины для backup базы `finpipe`.
- Traect должен учитываться как SQLite-сервис, а не как PostgreSQL-сервис.

## RPO

TODO

## RTO

TODO
