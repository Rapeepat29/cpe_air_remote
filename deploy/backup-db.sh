#!/usr/bin/env bash
# สำรองฐานข้อมูลเป็นไฟล์ .sql.gz ที่ /opt/rmutt/backups
#
# cron เรียกทุกวัน 02:30 (ตั้งโดย setup-vps.sh) เก็บย้อนหลังตาม
# BACKUP_KEEP_DAYS และส่งสำเนาไปเก็บนอกเครื่องถ้าตั้ง BACKUP_REMOTE ไว้
#
# กู้คืน:
#   gunzip -c backups/rmutt-YYYY-MM-DD_HHMM.sql.gz | \
#     docker compose exec -T db mariadb -uroot -p"<DB_ROOT_PASSWORD>" rmutt_save_energy
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

read_env() {
  grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"\r'
}

DB_DATABASE="$(read_env DB_DATABASE)"
DB_ROOT_PASSWORD="$(read_env DB_ROOT_PASSWORD)"
# .env รุ่นเก่าใช้ DB_PASSWORD เป็นรหัส root
[ -n "$DB_ROOT_PASSWORD" ] || DB_ROOT_PASSWORD="$(read_env DB_PASSWORD)"
KEEP_DAYS="$(read_env BACKUP_KEEP_DAYS)"
KEEP_DAYS="${KEEP_DAYS:-14}"
REMOTE="$(read_env BACKUP_REMOTE)"

mkdir -p backups
chmod 700 backups
FILE="backups/rmutt-$(date +%F_%H%M).sql.gz"
TMP="$FILE.partial"

# --single-transaction อ่านข้อมูลชุดเดียวกันทั้งไฟล์โดยไม่ล็อกตาราง
# ระบบยังบันทึกค่าไฟต่อได้ระหว่างสำรอง
docker compose exec -T db mariadb-dump -uroot -p"$DB_ROOT_PASSWORD" \
  --single-transaction --routines --triggers --events \
  "$DB_DATABASE" | gzip -9 > "$TMP"

# ไฟล์ที่ dump ไม่ครบ (เช่น db ล่มกลางทาง) จะไม่ถูกนับเป็น backup
if ! gzip -t "$TMP" || [ "$(gunzip -c "$TMP" | tail -1 | grep -c 'Dump completed')" -eq 0 ]; then
  rm -f "$TMP"
  echo "$(date '+%F %T') สำรองไม่สำเร็จ: ไฟล์ไม่สมบูรณ์" >&2
  exit 1
fi
mv "$TMP" "$FILE"
chmod 600 "$FILE"
echo "$(date '+%F %T') สำรองแล้ว: $FILE ($(du -h "$FILE" | cut -f1))"

find backups -name 'rmutt-*.sql.gz' -mtime +"$KEEP_DAYS" -delete

if [ -n "$REMOTE" ]; then
  # ต้องตั้ง SSH key ของ root ไปยังปลายทางไว้ก่อน (ssh-copy-id)
  if rsync -a --delete backups/ "$REMOTE/"; then
    echo "$(date '+%F %T') ส่งสำเนาไป $REMOTE แล้ว"
  else
    echo "$(date '+%F %T') ส่งสำเนาไป $REMOTE ไม่สำเร็จ" >&2
    exit 1
  fi
fi
