#!/usr/bin/env bash
# ดูข้อมูลในฐานข้อมูลแบบอ่านอย่างเดียว
# ใช้งาน:  bash db-view.sh            -> สรุปทุกตาราง
#          bash db-view.sh users      -> เจาะดูตารางเดียว
#          bash db-view.sh sql "SELECT ..."   -> รันคำสั่งเอง
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DB_PASSWORD="$(grep -E '^DB_ROOT_PASSWORD=' .env | head -1 | cut -d= -f2- | tr -d '"\r')"
# .env รุ่นเก่าใช้ DB_PASSWORD เป็นรหัส root
[ -n "$DB_PASSWORD" ] || DB_PASSWORD="$(grep -E '^DB_PASSWORD=' .env | head -1 | cut -d= -f2- | tr -d '"\r')"
DB_DATABASE="$(grep -E '^DB_DATABASE=' .env | head -1 | cut -d= -f2- | tr -d '"\r')"

run() {
  docker compose exec -T db mariadb -uroot -p"$DB_PASSWORD" "$DB_DATABASE" \
    --table -e "$1"
}

section() {
  printf '\n\033[1;36m===== %s =====\033[0m\n' "$1"
}

case "${1:-summary}" in
  sql)
    run "${2:?ใส่คำสั่ง SQL ต่อท้ายด้วย}"
    ;;

  users)
    section 'ผู้ใช้'
    run "SELECT username, CONCAT(first_name,' ',last_name) AS name,
                email, phone, role, is_active, last_login_at
           FROM users ORDER BY role, username;"
    ;;

  rooms)
    section 'ห้อง'
    run "SELECT room_number, floor_number, room_type, is_active
           FROM rooms ORDER BY floor_number, room_index;"
    ;;

  air)
    section 'เครื่องปรับอากาศ'
    run "SELECT device_id, room_number, air_number, name, protocol,
                provision_status, is_online, pzem_available, ac_running,
                voltage, power_watts, energy_kwh, last_seen_at
           FROM air_conditioners ORDER BY room_number, air_number;"
    ;;

  occupancy)
    section 'เซ็นเซอร์ตรวจจับคน'
    run "SELECT device_id, room_number, provision_status, is_online,
                radar_available, is_occupied, static_threshold, last_seen_at
           FROM occupancy_sensors ORDER BY room_number;"
    ;;

  schedules)
    section 'ตารางเรียน'
    run "SELECT room_number, day_of_week, start_time, end_time,
                subject_name, section_name, instructor
           FROM class_schedules ORDER BY room_number, day_of_week, start_time;"
    ;;

  summary | *)
    section 'จำนวนแถวแต่ละตาราง'
    run "SELECT 'users' AS ตาราง, COUNT(*) AS จำนวน FROM users
         UNION ALL SELECT 'rooms', COUNT(*) FROM rooms
         UNION ALL SELECT 'class_schedules', COUNT(*) FROM class_schedules
         UNION ALL SELECT 'air_conditioners', COUNT(*) FROM air_conditioners
         UNION ALL SELECT 'occupancy_sensors', COUNT(*) FROM occupancy_sensors
         UNION ALL SELECT 'password_reset_otps', COUNT(*) FROM password_reset_otps;"

    section 'ผู้ใช้'
    run "SELECT username, CONCAT(first_name,' ',last_name) AS name,
                role, is_active, last_login_at
           FROM users ORDER BY role, username;"

    section 'เครื่องปรับอากาศ'
    run "SELECT device_id, room_number, air_number, provision_status,
                is_online, power_watts, last_seen_at
           FROM air_conditioners ORDER BY room_number, air_number;"

    section 'เซ็นเซอร์ตรวจจับคน'
    run "SELECT device_id, room_number, provision_status, is_online,
                radar_available, is_occupied, last_seen_at
           FROM occupancy_sensors ORDER BY room_number;"

    printf '\nดูเพิ่ม: bash db-view.sh [users|rooms|air|occupancy|schedules]\n'
    printf 'รัน SQL เอง: bash db-view.sh sql "SELECT * FROM rooms LIMIT 5;"\n'
    ;;
esac
