#!/usr/bin/env bash
# Деплой tuya_local (форк Flegm + upstream) на Home Assistant
set -euo pipefail

HA_HOST="${HA_HOST:-192.168.1.89}"
HA_PORT="${HA_PORT:-222}"
HA_USER="${HA_USER:-root}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_TAG="${UPSTREAM_TAG:-2026.8.0}"
TMP="/tmp/tuya-local-deploy-$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "→ Скачиваем upstream ${UPSTREAM_TAG}..."
mkdir -p "$TMP"
curl -sfL "https://github.com/make-all/tuya-local/archive/refs/tags/${UPSTREAM_TAG}.zip" -o "$TMP/upstream.zip"
unzip -qo "$TMP/upstream.zip" -d "$TMP"
UPSTREAM_DIR="$TMP/tuya-local-${UPSTREAM_TAG}"

echo "→ Копируем fork-only device configs..."
for f in "$SCRIPT_DIR"/custom_components/tuya_local/devices/*.yaml; do
  base="$(basename "$f")"
  if [ ! -f "$UPSTREAM_DIR/custom_components/tuya_local/devices/$base" ]; then
    cp "$f" "$UPSTREAM_DIR/custom_components/tuya_local/devices/"
    echo "   + $base"
  fi
done

echo "→ Бэкап на HA..."
ssh -p "$HA_PORT" "${HA_USER}@${HA_HOST}" \
  "cp -a /config/custom_components/tuya_local /config/custom_components_backup/tuya_local.bak-\$(date +%Y%m%d-%H%M) 2>/dev/null || true"

echo "→ Деплой..."
ssh -p "$HA_PORT" "${HA_USER}@${HA_HOST}" "rm -rf /config/custom_components/tuya_local"
scp -rq -P "$HA_PORT" "$UPSTREAM_DIR/custom_components/tuya_local" \
  "${HA_USER}@${HA_HOST}:/config/custom_components/"

echo "→ Проверка конфигурации..."
ssh -p "$HA_PORT" "${HA_USER}@${HA_HOST}" 'ha core check'

echo "→ Перезапуск Home Assistant..."
ssh -p "$HA_PORT" "${HA_USER}@${HA_HOST}" 'ha core restart'

grep '"version"' "$UPSTREAM_DIR/custom_components/tuya_local/manifest.json"
echo "✓ tuya_local ${UPSTREAM_TAG} задеплоен"
