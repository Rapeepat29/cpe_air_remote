#!/usr/bin/env bash
# รันบน VPS เท่านั้น ถูกอัปโหลดมาพร้อมซอร์ส backend โดย update-server.ps1
#
# ทำ 6 อย่าง: build backend ใหม่ -> รอให้พร้อม -> migrate ฐานข้อมูล ->
# รีสตาร์ท -> โหลด Caddy ใหม่ให้รู้จักเว็บแอป -> ตรวจว่าใช้งานได้จริง
set -uo pipefail

cd /opt/rmutt || { echo "ไม่พบ /opt/rmutt"; exit 1; }

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31mล้มเหลว: %s\033[0m\n' "$1"; exit 1; }

# อ่าน DOMAIN ด้วย grep ไม่ใช่ source เพราะบางบรรทัดใน .env มีช่องว่าง
DOMAIN=$(grep -E '^DOMAIN=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
[ -n "$DOMAIN" ] || fail 'อ่าน DOMAIN จาก /opt/rmutt/.env ไม่ได้'
echo "โดเมน: $DOMAIN"

# ระบบเก่าใช้บัญชี MQTT เดียวทุกบอร์ด (ไฟล์ passwords) ระบบใหม่ใช้
# Dynamic Security ถ้ายังไม่มีไฟล์บัญชี Mosquitto จะไม่ยอมให้ใครต่อเลย
# โฟลเดอร์ mosquitto/data เป็นของ uid 1883 สิทธิ์ 700 ผู้ใช้ทั่วไปมองไม่เห็นไฟล์ข้างใน
# [ -f ] ตรง ๆ จึงตอบว่าไม่มีเสมอ ทั้งที่มีอยู่จริง ให้ถามผ่าน container mqtt หรือ sudo แทน
dynsec_exists() {
  local f=mosquitto/data/dynamic-security.json
  [ -f "$f" ] && return 0
  docker exec rmutt-mqtt test -f /mosquitto/data/dynamic-security.json 2>/dev/null && return 0
  sudo -n test -f "$f" 2>/dev/null && return 0
  # อ่านโฟลเดอร์ไม่ได้และตรวจทางอื่นไม่ได้ อย่าสรุปว่าไม่มี
  if [ -d mosquitto/data ] && [ ! -x mosquitto/data ]; then
    echo 'เตือน: ตรวจ dynamic-security.json ไม่ได้ (ไม่มีสิทธิ์อ่าน mosquitto/data) ข้ามการตรวจ'
    return 0
  fi
  return 1
}
if ! dynsec_exists; then
  fail 'ยังไม่มี mosquitto/data/dynamic-security.json ให้รัน: sudo bash init-env.sh'
fi
if ! grep -q '^MQTT_DEVICE_SECRET=.\+' .env; then
  fail '.env ยังไม่มี MQTT_DEVICE_SECRET ให้รัน: sudo bash init-env.sh'
fi
if ! grep -q '^DB_ROOT_PASSWORD=.\+' .env; then
  echo 'เตือน: .env ยังเป็นรุ่นเก่า (Backend ใช้ root ต่อฐานข้อมูล)'
  echo '       ดูวิธีย้ายไปใช้ user แยกใน DEPLOY.md หัวข้อ "ย้ายจากระบบเดิม"'
fi
mkdir -p firmware backups
# Backend (user node uid 1000) ต้องเขียนโฟลเดอร์ firmware ได้ เพื่อรับไฟล์ที่อัปโหลดจากเว็บ
if [ "$(stat -c %u firmware)" != 1000 ]; then
  chown 1000:1000 firmware 2>/dev/null || sudo -n chown 1000:1000 firmware 2>/dev/null \
    || echo 'เตือน: เปลี่ยนเจ้าของ firmware ไม่ได้ อัปโหลดเฟิร์มแวร์จากเว็บจะไม่สำเร็จ ให้รัน: sudo chown 1000:1000 /opt/rmutt/firmware'
fi

step '1/6 Build backend ใหม่'
# รหัสแอดมินตัวแรกใช้แค่ตอน seed ครั้งแรก ไม่ต้องค้างเป็นข้อความธรรมดาใน .env
# (สร้างแอดมินใหม่หรือรีเซ็ตรหัสภายหลังได้ด้วย: bash seed-admin.sh)
if grep -qE '^SEED_ADMIN_PASSWORD=.+' .env; then
  if sed -i 's/^SEED_ADMIN_PASSWORD=.*/SEED_ADMIN_PASSWORD=/' .env 2>/dev/null; then
    echo 'ลบ SEED_ADMIN_PASSWORD ที่ค้างอยู่ใน .env แล้ว'
  else
    echo 'เตือน: ลบ SEED_ADMIN_PASSWORD ใน .env ไม่ได้ ให้แก้เอง: sudo nano /opt/rmutt/.env'
  fi
fi

cp -f backend.Dockerfile backend/Dockerfile
docker compose up -d --build backend || fail 'build backend ไม่สำเร็จ'

step '2/6 รอให้ backend พร้อมรับคำสั่ง'
ready=0
for _ in $(seq 1 40); do
  if docker compose exec -T backend node -e 'process.exit(0)' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[ "$ready" = 1 ] || fail 'backend ไม่ขึ้นภายใน 80 วินาที ดูด้วย: docker compose logs backend'
echo 'พร้อมแล้ว'

step '3/6 อัปเดตโครงสร้างฐานข้อมูล'
# แต่ละคำสั่งปลอดภัยที่จะรันซ้ำ ถ้ามีอยู่แล้วจะข้ามให้เอง
docker compose exec -T backend node scripts/migrate-energy-history-v370.js \
  || fail 'migrate energy ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-auto-off-v380.js \
  || fail 'migrate auto-off ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-system-settings-v3100.js \
  || fail 'migrate system settings ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-firmware-v3140.js \
  || fail 'migrate firmware ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-offline-history-v3150.js \
  || fail 'migrate offline history ไม่สำเร็จ'
# เอาคอลัมน์ rooms.is_active และสถานะ 'removed' ที่ไม่ใช้แล้วออก (ต้องรันหลัง backend รุ่นใหม่ขึ้น)
docker compose exec -T backend node scripts/migrate-drop-unused.js \
  || fail 'migrate ลบส่วนที่ไม่ใช้ ไม่สำเร็จ'
docker compose exec -T backend node scripts/doctor.js --fix \
  || fail 'doctor ไม่สำเร็จ'
# ใบรับรองของ MQTTS อาจถูกต่ออายุไปแล้วระหว่างที่ไม่ได้อัปเดต
bash sync-mqtt-cert.sh || echo 'เตือน: sync-mqtt-cert.sh ไม่สำเร็จ (รันด้วย sudo)'

step '4/6 รีสตาร์ท backend ให้รู้จักตารางใหม่'
docker compose restart backend || fail 'รีสตาร์ทไม่สำเร็จ'
sleep 6
docker compose ps

step '5/6 เว็บแอปและ Caddy'
if [ -f www/index.html ] && [ -d www/assets/js ]; then
  files=$(find www -type f | wc -l)
  echo "พบไฟล์เว็บแอป $files ไฟล์ใน /opt/rmutt/www"
else
  echo 'เตือน: ยังไม่พบเว็บแอปใน /opt/rmutt/www'
  echo '       ให้รัน .\deploy\deploy-web.ps1 จากเครื่อง Windows'
  echo '       (ต้นทางคือโฟลเดอร์ webapp\ ของโปรเจกต์)'
fi
# Caddy อ่านไฟล์เว็บจากดิสก์ทุกครั้งอยู่แล้ว แต่ Caddyfile ต้องโหลดใหม่
docker compose up -d caddy >/dev/null 2>&1
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
  && echo 'โหลด Caddyfile ใหม่แล้ว' \
  || echo 'เตือน: reload Caddy ไม่สำเร็จ ลองดู: docker compose logs --tail 40 caddy'

# tailscale-serve.json ถูกอัปโหลดทับเป็นไฟล์ใหม่ container เดิมยังเห็นไฟล์เก่า
# ต้องสร้าง container ใหม่ (สถานะล็อกอินอยู่ใน ./tailscale/state ไม่หาย)
if docker compose ps --services 2>/dev/null | grep -qx tailscale; then
  docker compose up -d --force-recreate tailscale >/dev/null 2>&1 \
    && echo 'โหลด tailscale-serve.json ใหม่แล้ว (เว็บ 443 + MQTT 8443)' \
    || echo 'เตือน: สร้าง container tailscale ใหม่ไม่สำเร็จ ลองดู: docker compose logs --tail 40 tailscale'
fi

step '6/6 ตรวจว่าใช้งานได้จริง'
health=$(curl -s --max-time 20 "https://$DOMAIN/api/health")
echo "health: $health"
case "$health" in
  *'"status":"ok"'*) echo 'API ตอบปกติ' ;;
  *) fail "API ยังไม่ตอบ ดูด้วย: docker compose logs --tail 60 backend" ;;
esac
case "$health" in
  *'"connected":true'*) echo 'MQTT เชื่อมต่ออยู่' ;;
  *) echo 'เตือน: MQTT ยังไม่เชื่อมต่อ ดูด้วย: docker compose logs --tail 40 mqtt' ;;
esac

# 401 = เส้นทางมีอยู่จริงแต่ยังไม่ได้ล็อกอิน / 404 = ยังไม่ได้ลงโค้ดใหม่
for path in /api/alerts /api/energy/summary /api/energy/live /api/settings; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$DOMAIN$path")
  if [ "$code" = "401" ]; then
    echo "OK   $path (401 = มีเส้นทางแล้ว รอ token)"
  else
    echo "ผิด  $path -> HTTP $code (ควรเป็น 401)"
  fi
done

# หน้าเว็บต้องตอบ 200 และมีคำว่า RMUTT อยู่ในเนื้อหา
web_code=$(curl -s -o /tmp/rmutt-web-check -w '%{http_code}' --max-time 20 "https://$DOMAIN/")
if [ "$web_code" = "200" ] && grep -q 'RMUTT' /tmp/rmutt-web-check; then
  echo "OK   /  (เว็บแอปเสิร์ฟได้)"
else
  echo "ผิด  /  -> HTTP $web_code (ควรเป็น 200 และมีคำว่า RMUTT)"
fi
rm -f /tmp/rmutt-web-check

# ถ้า / ยัง 404 ทั้งที่ไฟล์อยู่ครบ แปลว่า bind mount ของ Caddy ชี้ไปที่
# โฟลเดอร์เก่าที่ถูกลบไปแล้ว (เกิดตอนใครสักคนเปลี่ยนชื่อโฟลเดอร์ www)
# สร้าง container ใหม่คือวิธีเดียวที่ผูก mount ใหม่ได้
if [ "$web_code" != "200" ] && [ -f www/index.html ]; then
  echo 'ไฟล์เว็บอยู่ครบแต่ Caddy มองไม่เห็น กำลังสร้าง container ใหม่...'
  docker compose up -d --force-recreate caddy >/dev/null 2>&1
  sleep 4
  web_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$DOMAIN/")
  if [ "$web_code" = "200" ]; then
    echo 'OK   /  (แก้ได้แล้วหลังสร้าง container ใหม่)'
  else
    echo "ยังไม่หาย / -> HTTP $web_code ดูด้วย: docker compose logs --tail 40 caddy"
  fi
fi

step 'ระบบปิดแอร์อัตโนมัติ'
if docker compose logs --tail 200 backend | grep -q 'Auto-off service started'; then
  echo 'ตัวคุมจังหวะปิดแอร์อัตโนมัติทำงานแล้ว'
else
  echo 'เตือน: ยังไม่เห็นข้อความ Auto-off service started ใน log'
fi

printf '\n\033[32mอัปเดตเซิร์ฟเวอร์เสร็จแล้ว\033[0m\n'
printf 'เว็บแอป: https://%s/\n' "$DOMAIN"
