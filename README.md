The Hub Infrastructure

Domains

* finpipe.net — Finpipe application
* grafana.finpipe.net — Grafana dashboards
* status.finpipe.net — Uptime Kuma

Services

Finpipe

Compose:

* docker/finpipe.compose.yml

Components:

* finpipe-web
* finpipe-bot
* postgres

Monitoring

Compose:

* docker/monitoring.compose.yml

Components:

* grafana
* loki
* prometheus
* alloy
* node-exporter

Status

Compose:

* docker/uptime-kuma.compose.yml

Components:

* uptime-kuma

Nginx

Configs:

* nginx/finpipe.net.conf
* nginx/grafana.finpipe.net.conf
* nginx/status.finpipe.net.conf
