## The Hub Infrastructure

Личная инфраструктура для Finpipe и связанных сервисов.

🌐 Domains

Domain	Purpose
finpipe.net	Основное приложение Finpipe
grafana.finpipe.net	Метрики, логи и мониторинг
status.finpipe.net	Страница состояния и uptime-мониторинг

⸻

📦 Finpipe

Основной сервис.

Compose:

docker/finpipe.compose.yml

Состав:

* finpipe-web — веб-интерфейс
* finpipe-bot — Telegram-бот
* postgres — база данных

⸻

📊 Monitoring Stack

Наблюдаем за тем, чтобы всё работало и было понятно почему не работает.

Compose:

docker/monitoring.compose.yml

Состав:

* Grafana — дашборды
* Loki — хранение логов
* Prometheus — сбор метрик
* Alloy — доставка логов и метрик
* Node Exporter — метрики VPS

⸻

💚 Status & Alerts

Проверка доступности сервисов и уведомления в Telegram.

Compose:

docker/uptime-kuma.compose.yml

Состав:

* Uptime Kuma

Мониторит:

* Finpipe
* Grafana
* VPS
* внутренние сервисы

⸻

🔀 Nginx

Точки входа для внешнего доступа.

Конфиги:

nginx/finpipe.net.conf
nginx/grafana.finpipe.net.conf
nginx/status.finpipe.net.conf

⸻

🚑 Recovery Notes

Полезно помнить:

* Grafana доступна через grafana.finpipe.net
* Uptime Kuma доступна через status.finpipe.net
* Все публичные сервисы работают через Nginx + Let’s Encrypt
* Мониторинг отправляет уведомления в Telegram
* Конфигурация инфраструктуры хранится в этом репозитории
