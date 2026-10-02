#!/usr/bin/env bash
# สร้าง .env พร้อมรหัสสุ่ม และบัญชี MQTT ของ Backend (Dynamic Security)
# ในขั้นตอนเดียว รันบนเซิร์ฟเวอร์ที่ /opt/rmutt ด้วย sudo
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  read -r -p ".env มีอยู่แล้ว เขียนทับไหม (พิมพ์ yes เพื่อยืนยัน): " confirm
  [ "$confirm" = "yes" ] || { echo "ยกเลิก"; exit 0; }
  cp .env ".env.bak-$(date +%Y%m%d-%H%M%S)"
  chmod 600 .env.bak-*
  if [ -d db/data/mysql ]; then
    echo ""
    echo "คำเตือน: มีฐานข้อมูลอยู่แล้วใน db/data"
    echo "  รหัส DB ใหม่จะใช้ไม่ได้กับฐานข้อมูลเดิม เพราะ MariaDB ตั้ง user"
    echo "  ครั้งเดียวตอนสร้าง ถ้าจะเก็บข้อมูลเดิม ให้กด Ctrl+C แล้วแก้ .env เอง"
    read -r -p "  ทำต่อ (พิมพ์ yes): " confirm_db
    [ "$confirm_db" = "yes" ] || { echo "ยกเลิก"; exit 0; }
  fi
fi

secret() { openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c "${1:-40}"; }

# upload.ps1 ไม่ส่งไฟล์ .env* ขึ้นเซิร์ฟเวอร์ .env.example จึงอาจไม่มี
# (ถ้าไม่มี grep จะ error แล้ว set -e ทำให้สคริปต์หยุดเงียบ ๆ)
DOMAIN_DEFAULT="$(grep -E '^DOMAIN=' .env.example 2>/dev/null | cut -d= -f2 || true)"
DOMAIN_DEFAULT="${DOMAIN_DEFAULT:-rmutt-energy.duckdns.org}"
read -r -p "โดเมนของเซิร์ฟเวอร์ [$DOMAIN_DEFAULT]: " DOMAIN
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"

DUCKDNS_TOKEN=""
case "$DOMAIN" in
  *.duckdns.org)
    echo "ใช้ DuckDNS: ต้องใช้ token จากหน้า https://www.duckdns.org (บรรทัด token)"
    while [ -z "$DUCKDNS_TOKEN" ]; do
      read -r -p "  DuckDNS token: " DUCKDNS_TOKEN
    done
    ;;
esac

read -r -s -p "รหัสผ่านแอดมินตัวแรกของแอป (อย่างน้อย 8 ตัว): " ADMIN_PASSWORD
echo ""
while [ "${#ADMIN_PASSWORD}" -lt 8 ]; do
  read -r -s -p "สั้นไป ลองใหม่: " ADMIN_PASSWORD
  echo ""
done
read -r -p "อีเมลแอดมิน: " ADMIN_EMAIL
read -r -p "เบอร์โทรแอดมิน [0800000000]: " ADMIN_PHONE
ADMIN_PHONE="${ADMIN_PHONE:-0800000000}"

echo ""
echo "อีเมลสำหรับส่ง OTP ลืมรหัสผ่าน (เว้นว่างได้ ระบบจะพิมพ์ OTP ลง log แทน)"
read -r -p "  SMTP host [smtp.gmail.com]: " SMTP_HOST
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
read -r -p "  บัญชีที่ใช้ส่ง (อีเมล): " SMTP_USER
SMTP_PASS=""
if [ -n "$SMTP_USER" ]; then
  read -r -s -p "  รหัสผ่าน SMTP (Gmail ใช้ App Password 16 ตัว): " SMTP_PASS
  echo ""
fi
MAIL_MODE="console"
[ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ] && MAIL_MODE="smtp"
# ช่องผู้ส่งต้องมีอีเมล ไม่งั้น SMTP ปฏิเสธและ OTP ไม่ถึงผู้ใช้
SMTP_FROM="RMUTT Save Energy <${SMTP_USER:-no-reply@$DOMAIN}>"

DB_ROOT_PASSWORD="$(secret 40)"
DB_PASSWORD="$(secret 40)"
JWT_SECRET="$(secret 48)"
OTP_PEPPER="$(secret 48)"
MQTT_USERNAME="rmutt_backend"
MQTT_PASSWORD="$(secret 32)"
MQTT_DEVICE_SECRET="$(secret 48)"

cat > .env <<EOF
DOMAIN=$DOMAIN
DUCKDNS_TOKEN=$DUCKDNS_TOKEN

DB_DATABASE=rmutt_save_energy
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_USER=rmutt_app
DB_PASSWORD=$DB_PASSWORD

JWT_SECRET=$JWT_SECRET
OTP_PEPPER=$OTP_PEPPER
JWT_EXPIRES_IN=8h
OTP_EXPIRES_MINUTES=10

MQTT_USERNAME=$MQTT_USERNAME
MQTT_PASSWORD=$MQTT_PASSWORD
MQTT_DEVICE_SECRET=$MQTT_DEVICE_SECRET

MAIL_MODE=$MAIL_MODE
SMTP_HOST=$SMTP_HOST
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=$SMTP_USER
SMTP_PASS=$SMTP_PASS
SMTP_FROM="$SMTP_FROM"

SEED_ADMIN_USERNAME=admin
SEED_ADMIN_PASSWORD=$ADMIN_PASSWORD
SEED_ADMIN_FIRST_NAME=System
SEED_ADMIN_LAST_NAME=Administrator
SEED_ADMIN_EMAIL=$ADMIN_EMAIL
SEED_ADMIN_PHONE=$ADMIN_PHONE

BACKUP_KEEP_DAYS=14
BACKUP_REMOTE=

LEGACY_PHONE_PREFIX=0
EOF
chmod 600 .env

# ---------------------------------------------- Mosquitto Dynamic Security
mkdir -p mosquitto/config mosquitto/data mosquitto/certs firmware backups

# หา path ของ plugin ใน image จริง แล้วเขียนลง mosquitto.conf
# (image แต่ละรุ่นวางไฟล์ไว้คนละที่ได้)
PLUGIN_PATH="$(docker run --rm eclipse-mosquitto:2.0 \
  sh -c 'find / -name mosquitto_dynamic_security.so 2>/dev/null | head -1')"
if [ -z "$PLUGIN_PATH" ]; then
  echo "ไม่พบ mosquitto_dynamic_security.so ใน image eclipse-mosquitto:2.0" >&2
  exit 1
fi
sed -i "s#^plugin .*#plugin $PLUGIN_PATH#" mosquitto/config/mosquitto.conf
echo "Dynamic Security plugin: $PLUGIN_PATH"

# สร้างไฟล์บัญชีใหม่ทุกครั้งที่สร้าง .env ใหม่ (รหัสของ Backend เปลี่ยน)
# บัญชีของบอร์ดไม่หาย เพราะ Backend สร้างคืนให้เองทุกครั้งที่ต่อ Broker
rm -f mosquitto/data/dynamic-security.json
docker run --rm -v "$ROOT/mosquitto/data:/mosquitto/data" \
  eclipse-mosquitto:2.0 \
  mosquitto_ctrl dynsec init /mosquitto/data/dynamic-security.json \
  "$MQTT_USERNAME" "$MQTT_PASSWORD" >/dev/null

# mosquitto ในคอนเทนเนอร์รันด้วย uid/gid 1883 ต้องเป็นเจ้าของไฟล์เหล่านี้
chown -R 1883:1883 mosquitto/data
chmod 700 mosquitto/data
chmod 600 mosquitto/data/dynamic-security.json
chmod 644 mosquitto/config/mosquitto.conf
# ไฟล์ของระบบเก่า (ใช้บัญชีเดียวทุกบอร์ด) ไม่ใช้แล้ว
rm -f mosquitto/config/passwords mosquitto/config/acl

# ให้ผู้ใช้ที่สั่ง sudo (อยู่ในกลุ่ม docker) อ่าน .env ได้ docker compose ต้องใช้
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  chown "$SUDO_USER":"$SUDO_USER" .env
fi

printf '\n\033[1;32m===== สร้าง .env และบัญชี MQTT แล้ว =====\033[0m\n'
echo "โดเมน          : $DOMAIN"
echo "โหมดอีเมล      : $MAIL_MODE"
echo "MQTT (Backend) : $MQTT_USERNAME"
echo ""
echo "รหัสผ่านทั้งหมดอยู่ใน /opt/rmutt/.env (อ่านได้เฉพาะ root)"
echo "บอร์ด ESP32 ไม่ใช้รหัสนี้ แต่ละบอร์ดได้รหัสของตัวเองตอนตั้งค่าผ่านบลูทูธ"
