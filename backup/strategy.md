# Backup Strategy

Этот документ фиксирует текущие решения по backup в `the-hub-infra`.

## Responsibilities

- Application-managed:
- `Finpipe`
- `Traect`
- `Echo`
- `Postbox`
- Infrastructure-managed:
- `Yo Registry`
- `Uptime Kuma`
- `Grafana`

Application-owned рабочие скрипты не заменяются, если они уже существуют и подтверждены в эксплуатации.

## PostgreSQL

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

## SQLite

- Plain `cp` небезопасен для live SQLite database.
- Для SQLite в `wal` mode это особенно важно, потому что согласованное состояние зависит от основного файла и sidecar-файлов WAL/SHM.
- `sqlite3 .backup` использует SQLite backup API и создаёт согласованный snapshot.
- Для infrastructure-managed SQLite backup используются только `Uptime Kuma` и `Grafana`.
- `Uptime Kuma` использует `wal` mode и поэтому должен резервироваться только безопасным snapshot-методом.
- `Grafana` находится внутри Docker volume и требует чтения с root-level доступом.
- `Postbox` остаётся application-managed и inactive до фактического deployment production DB.

## Filesystem Backup Policy

- Резервируются только невосстановимые файлы.
- Временные uploads не резервируются.
- Данные, полностью содержащиеся в PostgreSQL, отдельно не резервируются.
- Файловые копии, являющиеся рабочим кэшем, не резервируются.
- `Yo Registry` processed images являются authoritative filesystem data.
- `Portainer` будет добавлен после внедрения.

## Exclusions

- `Prometheus TSDB` и `Loki data` по-прежнему исключены из обязательных backup-задач.
- Их история считается восстанавливаемой или некритичной, пока не появятся требования по долгосрочному хранению или аудиту.

## RPO

TODO

## RTO

TODO
