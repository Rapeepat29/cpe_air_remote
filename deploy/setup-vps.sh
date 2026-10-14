#!/usr/bin/env bash
# ติดตั้งพื้นฐานบนเซิร์ฟเวอร์ Ubuntu 22.04/24.04 (รันครั้งเดียวตอนเครื่องใหม่)
#
# ใช้ได้ทั้ง VPS และเซิร์ฟเวอร์ของมหาวิทยาลัย
#   sudo bash setup-vps.sh              ติดตั้งทุกอย่าง ยกเว้น firewall
#   sudo bash setup-vps.sh --firewall   ตั้ง ufw ด้วย (อย่าใช้ถ้าฝ่ายไอที
#                                       ดูแล firewall ให้อยู่แล้ว)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "ต้องรันด้วย sudo" >&2
  exit 1
fi

WITH_FIREWALL=0
[ "${1:-}" = "--firewall" ] && WITH_FIREWALL=1
APP_DIR=/opt/rmutt
# ผู้ใช้ที่สั่ง sudo จะได้ใช้ docker และจัดการ /opt/rmutt ได้โดยไม่ต้องเป็น root
OWNER="${SUDO_USER:-root}"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

step "1/7 อัปเดตระบบ"
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg ufw fail2ban cron dnsutils \
  openssl gzip rsync

step "2/7 ติดตั้ง Docker"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
if [ "$OWNER" != "root" ]; then
  usermod -aG docker "$OWNER"
  echo "เพิ่ม $OWNER เข้ากลุ่ม docker แล้ว (ออกจาก SSH แล้วเข้าใหม่หนึ่งครั้ง)"
fi

step "3/7 สร้าง swap 2GB (ถ้ายังไม่มี)"
if [ "$(swapon --show | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
  echo 'vm.swappiness=10' >/etc/sysctl.d/99-swappiness.conf
  sysctl -p /etc/sysctl.d/99-swappiness.conf >/dev/null
else
  echo "มี swap อยู่แล้ว"
fi

step "4/7 ตั้งเวลาและ NTP"
timedatectl set-timezone Asia/Bangkok
timedatectl set-ntp true || echo "เตือน: เปิด NTP ไม่ได้ ให้ฝ่ายไอทีตรวจ (เวลาผิด = TLS ใช้ไม่ได้)"

step "5/7 firewall"
if [ "$WITH_FIREWALL" = "1" ]; then
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp   comment 'SSH' >/dev/null
  ufw allow 80/tcp   comment 'HTTP (Lets Encrypt)' >/dev/null
  ufw allow 443/tcp  comment 'HTTPS' >/dev/null
  ufw allow 8883/tcp comment 'MQTTS' >/dev/null
  ufw --force enable >/dev/null
  ufw status numbered | sed -n '1,12p'
else
  echo "ข้าม (ใช้ --firewall ถ้าต้องการให้สคริปต์ตั้ง ufw เอง)"
  echo "พอร์ตที่ต้องเปิดจากภายนอก: 80, 443, 8883 และ 22 สำหรับผู้ดูแล"
fi

step "6/7 วางโครงไฟล์ที่ $APP_DIR"
mkdir -p "$APP_DIR"/{db/data,mosquitto/{config,certs,data},caddy/{data,config},backend,www,firmware,backups}
chown -R "$OWNER":"$OWNER" "$APP_DIR"
# ข้อมูลของ mosquitto ต้องเป็นของ uid 1883 ที่ใช้ในคอนเทนเนอร์
chown -R 1883:1883 "$APP_DIR/mosquitto/data" "$APP_DIR/mosquitto/certs"
# backend (user node uid 1000) รับไฟล์เฟิร์มแวร์ที่อัปโหลดจากเว็บ
chown 1000:1000 "$APP_DIR/firmware"
chmod 750 "$APP_DIR"
chmod 700 "$APP_DIR/backups"

step "7/7 งานตามเวลา (cron ของ root)"
# ใบรับรองของ Caddy ต่ออายุเองทุก ~60 วัน ต้องก๊อปให้ Mosquitto ด้วย
# ไม่งั้นพอใบเก่าหมดอายุ บอร์ด ESP32 ทุกตัวจะต่อ MQTT ไม่ได้พร้อมกัน
CRON_FILE=/etc/cron.d/rmutt
cat >"$CRON_FILE" <<EOF
# RMUTT Save Energy
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# ก๊อปใบรับรอง HTTPS ให้ Mosquitto ทุกวัน 03:10
10 3 * * * root bash $APP_DIR/sync-mqtt-cert.sh >> /var/log/rmutt-cert.log 2>&1
# สำรองฐานข้อมูลทุกวัน 02:30
30 2 * * * root bash $APP_DIR/backup-db.sh >> /var/log/rmutt-backup.log 2>&1
EOF
chmod 644 "$CRON_FILE"
echo "ตั้ง $CRON_FILE แล้ว"

printf '\n\033[1;32m===== ติดตั้งเสร็จ =====\033[0m\n'
docker --version
docker compose version
timedatectl | sed -n '1,4p'
free -h | sed -n '1,3p'
df -h / | tail -1
