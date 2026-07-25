#!/usr/bin/env bash
# Export The Hub dashboards from Grafana into JSON files for git backup.
#
# MVP: складывает текущее состояние дашбордов в ./dashboards/<uid>.json.
# Пригодится как бэкап, для code review изменений и для переезда/пересборки.
#
# Usage:
#   export GRAFANA_URL=https://grafana.finpipe.net
#   export GRAFANA_TOKEN=<service-account-token>   # роли Viewer достаточно
#   ./export-dashboards.sh
#
# Токен: Grafana -> Administration -> Users and access -> Service accounts ->
#        создать SA (роль Viewer) -> Add service account token.
#
# Требуется: curl, jq
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-https://grafana.finpipe.net}"
: "${GRAFANA_TOKEN:?Set GRAFANA_TOKEN (Grafana service account token)}"

DIR="$(cd "$(dirname "$0")" && pwd)/dashboards"
mkdir -p "$DIR"

# Дашборды folder "The Hub". Добавляй новые uid сюда.
UIDS=(
  the-hub-00-overview
  the-hub-10-infra
  the-hub-15-apps
  the-hub-40-logs
)

for uid in "${UIDS[@]}"; do
  echo "Exporting ${uid} ..."
  curl -sf -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${GRAFANA_URL}/api/dashboards/uid/${uid}" \
    | jq '.dashboard | .id = null | del(.version)' \
    > "${DIR}/${uid}.json"
done

echo "Done. JSON saved to ${DIR}"
