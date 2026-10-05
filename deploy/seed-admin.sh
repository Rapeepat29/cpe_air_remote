#!/usr/bin/env bash
# สร้างบัญชีแอดมินตัวแรก (หรือรีเซ็ตรหัสแอดมินคนนั้น) แล้วลบรหัสผ่านออกจาก .env
#
# ใช้งาน (บนเซิร์ฟเวอร์ ที่ /opt/rmutt):  bash seed-admin.sh
#
# ทำไมไม่ใช้ `docker compose exec backend npm run seed:admin` แบบเดิม:
#   Backend ไม่ได้รับ .env ทั้งไฟล์แล้ว (ดู docker-compose.yml) รหัสแอดมินจึงไม่อยู่ใน
#   container สคริปต์นี้อ่านค่าจาก .env แล้วส่งรหัสผ่านเข้าไปทาง stdin ครั้งเดียว
#   เสร็จแล้วล้าง SEED_ADMIN_PASSWORD ใน .env ไม่ให้รหัสแอดมินค้างเป็นข้อความธรรมดา
#
# ถ้า .env ไม่มี SEED_ADMIN_PASSWORD แล้ว (เคยรันไปแล้ว) สคริปต์จะถามรหัสใหม่
# การรันซ้ำ = ตั้งรหัสแอดมินคนนี้ใหม่ และทุกเครื่องที่ล็อกอินค้างจะต้องเข้าใหม่
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
  echo "ไม่พบ .env ให้รัน: sudo bash init-env.sh ก่อน" >&2
  exit 1
fi

value() {
  grep -E "^$1=" .env | head -1 | cut -d= -f2- | tr -d '\r' \
    | sed -e 's/^"\(.*\)"$/\1/'
}

USERNAME="$(value SEED_ADMIN_USERNAME)"
USERNAME="${USERNAME:-admin}"
EMAIL="$(value SEED_ADMIN_EMAIL)"
PHONE="$(value SEED_ADMIN_PHONE)"
FIRST_NAME="$(value SEED_ADMIN_FIRST_NAME)"
LAST_NAME="$(value SEED_ADMIN_LAST_NAME)"
PASSWORD="$(value SEED_ADMIN_PASSWORD)"

if [ -z "$EMAIL" ]; then
  read -r -p "อีเมลแอดมิน: " EMAIL
fi
if [ -z "$PHONE" ]; then
  read -r -p "เบอร์โทรแอดมิน [0800000000]: " PHONE
  PHONE="${PHONE:-0800000000}"
fi
if [ -z "$PASSWORD" ]; then
  read -r -s -p "รหัสผ่านแอดมิน $USERNAME (อย่างน้อย 8 ตัว): " PASSWORD
  echo ""
fi

printf '%s' "$PASSWORD" | docker compose exec -T \
  -e SEED_ADMIN_USERNAME="$USERNAME" \
  -e SEED_ADMIN_EMAIL="$EMAIL" \
  -e SEED_ADMIN_PHONE="$PHONE" \
  -e SEED_ADMIN_FIRST_NAME="$FIRST_NAME" \
  -e SEED_ADMIN_LAST_NAME="$LAST_NAME" \
  backend node scripts/seed-admin.js --password-stdin

if grep -qE '^SEED_ADMIN_PASSWORD=.+' .env; then
  sed -i 's/^SEED_ADMIN_PASSWORD=.*/SEED_ADMIN_PASSWORD=/' .env
  echo "ลบ SEED_ADMIN_PASSWORD ออกจาก .env แล้ว (จำรหัสแอดมินไว้เอง หรือเก็บในที่ปลอดภัย)"
fi
