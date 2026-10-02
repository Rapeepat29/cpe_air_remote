#!/usr/bin/env bash
# แก้สิทธิ์ไฟล์ให้ mosquitto (รันด้วย uid 1883 ในคอนเทนเนอร์) อ่านได้
# ใช้เมื่อ rmutt-mqtt วน Restarting
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "== log ล่าสุดของ mqtt =="
docker compose logs --tail 15 mqtt || true

echo ""
echo "== ไฟล์ก่อนแก้ =="
ls -l mosquitto/config mosquitto/certs mosquitto/data 2>/dev/null || true

missing=0
for file in mosquitto/config/mosquitto.conf \
            mosquitto/data/dynamic-security.json \
            mosquitto/certs/fullchain.pem mosquitto/certs/privkey.pem; do
  if [ ! -f "$file" ]; then
    echo "ไม่มีไฟล์: $file"
    missing=1
  fi
done

if [ "$missing" = "1" ]; then
  echo ""
  echo "ไฟล์ไม่ครบ"
  echo "  ขาดใบรับรอง -> bash sync-mqtt-cert.sh"
  echo "  ขาด dynamic-security.json -> bash init-env.sh"
  exit 1
fi

chown -R 1883:1883 mosquitto/data mosquitto/certs
chmod 700 mosquitto/data
chmod 600 mosquitto/data/dynamic-security.json mosquitto/certs/privkey.pem
chmod 644 mosquitto/config/mosquitto.conf mosquitto/certs/fullchain.pem

echo ""
echo "== ไฟล์หลังแก้ =="
ls -l mosquitto/config mosquitto/certs mosquitto/data

docker compose restart mqtt
sleep 6
echo ""
echo "== สถานะ =="
docker compose ps
docker compose logs --tail 12 mqtt
