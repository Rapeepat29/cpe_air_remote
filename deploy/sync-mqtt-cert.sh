#!/usr/bin/env bash
# ก๊อปใบรับรองจาก Caddy ไปให้ Mosquitto ใช้ที่พอร์ต 8883 แล้วสั่ง reload
# cron เรียกทุกวัน (ตั้งโดย setup-vps.sh) จะ reload เฉพาะเมื่อใบเปลี่ยนจริง
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# อ่านเฉพาะค่าที่ต้องใช้ ไม่ source ทั้งไฟล์
# เพราะค่าที่มีเว้นวรรค เช่น SMTP_FROM จะทำให้ bash ตีความเป็นคำสั่ง
DOMAIN="$(grep -E '^DOMAIN=' .env | head -1 | cut -d= -f2- | tr -d '"\r' | xargs)"

if [ -z "${DOMAIN:-}" ]; then
  echo "ไม่พบ DOMAIN ใน .env"
  exit 1
fi

CERT_DIR="$ROOT/caddy/data/caddy/certificates"
TARGET="$ROOT/mosquitto/certs"

if [ ! -d "$CERT_DIR" ]; then
  echo "ยังไม่มีใบรับรอง: Caddy ขอไม่สำเร็จ ตรวจ DNS และพอร์ต 80"
  echo "  docker compose logs caddy | tail -30"
  exit 1
fi

SRC_CRT="$(find "$CERT_DIR" -name "${DOMAIN}.crt" | head -1)"
SRC_KEY="$(find "$CERT_DIR" -name "${DOMAIN}.key" | head -1)"

if [ -z "$SRC_CRT" ] || [ -z "$SRC_KEY" ]; then
  echo "หาใบรับรองของ ${DOMAIN} ไม่เจอ"
  find "$CERT_DIR" -name '*.crt' | head
  exit 1
fi

mkdir -p "$TARGET"
if cmp -s "$SRC_CRT" "$TARGET/fullchain.pem" \
  && cmp -s "$SRC_KEY" "$TARGET/privkey.pem"; then
  echo "$(date '+%F %T') ใบรับรองยังเป็นใบเดิม ไม่ต้อง reload"
  exit 0
fi

cp "$SRC_CRT" "$TARGET/fullchain.pem"
cp "$SRC_KEY" "$TARGET/privkey.pem"
chown 1883:1883 "$TARGET/fullchain.pem" "$TARGET/privkey.pem"
chmod 644 "$TARGET/fullchain.pem"
chmod 600 "$TARGET/privkey.pem"

echo "$(date '+%F %T') ก๊อปใบรับรองใหม่แล้ว"
openssl x509 -in "$TARGET/fullchain.pem" -noout -subject -issuer -enddate

if docker ps --format '{{.Names}}' | grep -q '^rmutt-mqtt$'; then
  # SIGHUP ทำให้ Mosquitto อ่านใบรับรองใหม่ โดยบอร์ดที่ต่ออยู่ไม่หลุด
  docker kill -s HUP rmutt-mqtt >/dev/null
  echo "Mosquitto โหลดใบรับรองใหม่แล้ว"
fi
