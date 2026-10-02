# 05 · Docker — รันโปรแกรมในกล่องสำเร็จรูป

> Docker ถูกใช้ทั้งบนเครื่องพัฒนา (Mosquitto, MariaDB) และบนเซิร์ฟเวอร์จริง (ทุกชิ้น)
> บทนี้อธิบายแนวคิด แล้วอ่านไฟล์ Docker ของโปรเจกต์ทุกบรรทัด

---

## 1. Docker แก้ปัญหาอะไร

ปัญหาเดิม: "เครื่องฉันรันได้ ทำไมเครื่องเธอรันไม่ได้"
- ติดตั้ง Mosquitto คนละรุ่น
- ไฟล์ตั้งค่าอยู่คนละที่
- Windows กับ Linux ต่างกัน

Docker แก้โดย **ห่อโปรแกรม + ทุกอย่างที่โปรแกรมต้องใช้** ไว้ในกล่องเดียว
แล้วกล่องนั้นรันเหมือนกันทุกเครื่อง

เปรียบเทียบ: แทนที่จะส่งสูตรอาหารให้ไปทำเอง (อาจได้รสไม่เหมือน) ส่ง **อาหารกล่องแช่แข็ง** ไปอุ่นกิน

---

## 2. ศัพท์หลัก 6 คำ

| ศัพท์ | ความหมาย | เปรียบเทียบ |
|---|---|---|
| **Image** | แม่แบบของกล่อง (อ่านอย่างเดียว) เช่น `eclipse-mosquitto:2.0` | แม่พิมพ์ขนม |
| **Container** | กล่องที่ถูกสร้างจาก image และ **กำลังรัน** | ขนมที่ออกจากแม่พิมพ์ |
| **Registry** (Docker Hub) | คลัง image ออนไลน์ | ร้านขายแม่พิมพ์ |
| **Tag** | รุ่นของ image หลังเครื่องหมาย `:` เช่น `:2.0`, `:11`, `:22-alpine` | รุ่นของแม่พิมพ์ |
| **Volume / Bind mount** | ที่เก็บข้อมูลที่ **อยู่นอกกล่อง** ลบกล่องแล้วข้อมูลไม่หาย | ตู้เย็นที่อยู่นอกกล่องขนม |
| **Port mapping** | ต่อพอร์ตของเครื่องจริง เข้าพอร์ตในกล่อง | ท่อเชื่อม |

อีก 2 คำที่เจอบ่อย

| ศัพท์ | ความหมาย |
|---|---|
| **Dockerfile** | สูตรสร้าง image เอง (โปรเจกต์ใช้กับ Backend) |
| **Docker Compose** | ไฟล์ `docker-compose.yml` ที่บอกว่า **จะรันหลายกล่องพร้อมกันอย่างไร** |

### ทำไมกล่องต้องมี Volume
Container **ถูกออกแบบให้ทิ้งได้** ลบแล้วสร้างใหม่ได้ตลอด ถ้าเก็บข้อมูลฐานข้อมูลไว้ในกล่อง
ลบกล่องเมื่อไร = ข้อมูลหายหมด จึงต้องเอาโฟลเดอร์ข้อมูลไปไว้ข้างนอก

---

## 3. Port mapping แบบภาพ

```text
เครื่อง Windows ของคุณ                         Container rmutt-mosquitto
┌─────────────────────────────┐               ┌──────────────────────┐
│ พอร์ต 1883  ─────────────────┼──────────────▶│ พอร์ต 1883           │
│ (ESP32 ต่อเข้ามาที่นี่)         │   "1883:1883" │ Mosquitto ฟังอยู่     │
└─────────────────────────────┘               └──────────────────────┘
```

รูปแบบ: `"พอร์ตเครื่องจริง:พอร์ตในกล่อง"`

| เขียนว่า | ความหมาย |
|---|---|
| `"1883:1883"` | ใครก็ได้ในเครือข่ายต่อพอร์ต 1883 ของเครื่องนี้ → เข้ากล่อง |
| `"127.0.0.1:3306:3306"` | **เฉพาะเครื่องนี้เอง** ต่อได้ คนอื่นในเครือข่ายต่อไม่ได้ (ปลอดภัยกว่า) |
| `"3307:3306"` | เครื่องจริงใช้ 3307 ในกล่องใช้ 3306 (ใช้ตอนพอร์ตชน) |

บนเซิร์ฟเวอร์จริง MariaDB ใช้ `"127.0.0.1:3306:3306"` เพื่อ **ไม่ให้เข้าจากอินเทอร์เน็ต**

---

## 4. คำสั่ง Docker ที่ต้องใช้

### 4.1 ดูสถานะ

```powershell
docker ps                     # container ที่กำลังรัน
docker ps -a                  # ทั้งหมด รวมที่หยุดแล้ว
docker images                 # image ที่ดาวน์โหลดไว้
docker volume ls              # volume ทั้งหมด
docker stats                  # ใช้ CPU/RAM เท่าไร (Ctrl+C ออก)
```

ตัวอย่างผลของ `docker ps`

```text
CONTAINER ID  IMAGE                  STATUS                  PORTS                    NAMES
a1b2c3d4e5f6  eclipse-mosquitto:2.0  Up 2 hours (healthy)    0.0.0.0:1883->1883/tcp   rmutt-mosquitto
f6e5d4c3b2a1  mariadb:11             Up 2 hours              0.0.0.0:3306->3306/tcp   mariadb
```

- `STATUS` ที่มี `(healthy)` = ผ่าน healthcheck (หัวข้อ 6)
- `(unhealthy)` = รันอยู่แต่ใช้ไม่ได้
- `Restarting` = พังแล้วเปิดใหม่วนไปเรื่อย ๆ

### 4.2 เปิด/ปิด/ลบ container เดี่ยว

```powershell
docker start mariadb          # เปิด container ที่มีอยู่แล้ว
docker stop mariadb           # หยุด (ข้อมูลยังอยู่)
docker restart mariadb        # ปิดแล้วเปิดใหม่
docker rm mariadb             # ลบ container (ต้องหยุดก่อน) ข้อมูลใน volume ยังอยู่
docker rm -f mariadb          # บังคับลบแม้กำลังรัน
```

### 4.3 ดู log

```powershell
docker logs rmutt-mosquitto              # log ทั้งหมด
docker logs --tail 50 rmutt-mosquitto    # 50 บรรทัดล่าสุด
docker logs -f rmutt-mosquitto           # ดูสด (follow) กด Ctrl+C ออก
```

### 4.4 เข้าไปสั่งงานในกล่อง

```powershell
docker exec -it mariadb mariadb -uroot -p
```

- `exec` = รันคำสั่งใน container ที่กำลังรัน
- `-i` = interactive (รับการพิมพ์), `-t` = จำลองหน้าจอ terminal
- `mariadb` (ตัวแรก) = ชื่อ container
- `mariadb -uroot -p` = คำสั่งที่จะรันข้างใน (โปรแกรม client ของ MariaDB, ผู้ใช้ root, ถามรหัส)

เข้า shell ในกล่อง

```powershell
docker exec -it rmutt-mosquitto sh
# ข้างในพิมพ์ ls /mosquitto/config แล้ว exit ออก
```

### 4.5 ตรวจรายละเอียด

```powershell
docker inspect rmutt-mosquitto
docker inspect --format '{{.State.Health.Status}}' rmutt-mosquitto
```

`--format '{{...}}'` = เลือกเฉพาะบางค่า (ภาษา Go template) สคริปต์ของโปรเจกต์ใช้บรรทัดนี้

```powershell
docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' rmutt-mosquitto
```

อ่านว่า "ถ้ามี healthcheck ให้บอกสถานะ health ถ้าไม่มีให้บอกสถานะธรรมดา"

### 4.6 ทำความสะอาด (ระวัง)

```powershell
docker system df              # ดูว่า Docker ใช้ดิสก์เท่าไร
docker image prune            # ลบ image ที่ไม่มีใครใช้
docker system prune           # ลบของที่ไม่ใช้ทั้งหมด (ไม่ลบ volume)
```

> ⚠️ `docker volume rm ...` และ `docker system prune --volumes` **ลบข้อมูลฐานข้อมูลถาวร**

---

## 5. Docker Compose — รันหลายกล่องด้วยไฟล์เดียว

แทนที่จะพิมพ์ `docker run` ยาว ๆ ทุกครั้ง เขียนค่าทั้งหมดลงไฟล์ `docker-compose.yml`
แล้วสั่งสั้น ๆ

### คำสั่ง Compose

> 📁 ต้องรันในโฟลเดอร์ที่มีไฟล์ `docker-compose.yml`

```powershell
docker compose up -d                 # สร้าง+เปิดทุก service เบื้องหลัง
docker compose up -d --build         # build image ใหม่ก่อน (เมื่อแก้โค้ด backend)
docker compose up -d backend         # เปิดเฉพาะ service ชื่อ backend
docker compose ps                    # สถานะของ service ในไฟล์นี้
docker compose logs -f backend       # log สดของ backend
docker compose logs --tail 80 mqtt   # 80 บรรทัดล่าสุดของ mqtt
docker compose restart backend       # รีสตาร์ท
docker compose stop                  # หยุด (ไม่ลบ)
docker compose down                  # หยุดและลบ container (volume ยังอยู่)
docker compose exec backend sh       # เข้า shell ใน service backend
docker compose exec backend npm run db:doctor   # รันคำสั่งใน backend
docker compose --env-file .env up -d # ระบุไฟล์ค่าตัวแปร
```

- **service** = ชื่อที่ตั้งในไฟล์ (เช่น `broker`, `db`, `backend`)
- **container_name** = ชื่อ container จริง (เช่น `rmutt-mosquitto`)
- คำสั่ง `docker compose ...` ใช้ **ชื่อ service**
- คำสั่ง `docker ...` ใช้ **ชื่อ container**

> 💡 `docker-compose` (มีขีด) คือรุ่นเก่า โปรเจกต์นี้ใช้ `docker compose` (เว้นวรรค)

---

## 6. อ่านไฟล์จริง #1: `mqtt/docker-compose.yml` (ใช้บนเครื่องพัฒนา)

```yaml
name: rmutt-save-energy                     # (1)

services:                                   # (2)
  broker:                                   # (3)
    image: eclipse-mosquitto:2.0            # (4)
    container_name: rmutt-mosquitto         # (5)
    restart: unless-stopped                 # (6)
    ports:
      - "1883:1883"                         # (7)
    environment:                            # (8)
      MQTT_USERNAME: ${MQTT_USERNAME}
      MQTT_PASSWORD: ${MQTT_PASSWORD}
    volumes:                                # (9)
      - ./config:/mosquitto/config:ro
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
    healthcheck:                            # (10)
      test:
        - CMD-SHELL
        - >-
          mosquitto_sub -h 127.0.0.1 -p 1883
          -u "$${MQTT_USERNAME}" -P "$${MQTT_PASSWORD}"
          -t '$$SYS/broker/version' -C 1 -W 5
      interval: 10s
      timeout: 6s
      retries: 6
      start_period: 5s
```

1. **name** = ชื่อกลุ่มของ container ทั้งหมดในไฟล์นี้
2. **services** = รายการกล่องที่จะรัน (ไฟล์นี้มีกล่องเดียว)
3. **broker** = ชื่อ service ใช้กับ `docker compose logs broker`
4. **image** = ใช้ Mosquitto รุ่น 2.0 จาก Docker Hub (ดาวน์โหลดอัตโนมัติครั้งแรก)
5. **container_name** = ชื่อจริง สคริปต์ `.ps1` อ้างถึงชื่อนี้
6. **restart: unless-stopped** = ถ้าพังหรือเปิดคอมใหม่ ให้เปิดเอง ยกเว้นเราสั่ง stop
7. **ports** = เปิดพอร์ต 1883 ให้ ESP32 ในวง Wi-Fi ต่อเข้ามาได้
8. **environment** = ส่งตัวแปรเข้ากล่อง `${MQTT_USERNAME}` ดึงค่าจากไฟล์ `mqtt/.env`
   (นั่นคือเหตุผลที่สคริปต์ใช้ `--env-file .env`)
9. **volumes** — รูปแบบ `ที่เครื่องจริง:ที่ในกล่อง[:ตัวเลือก]`
   - `./config` → `/mosquitto/config` แบบ `:ro` (read-only) กล่องแก้ไฟล์ตั้งค่าไม่ได้
   - `./data` → เก็บข้อความที่ต้องจำ (retained) ข้ามการรีสตาร์ท
   - `./log` → ไฟล์ log เปิดดูได้จาก Windows ที่ `mqtt\log\mosquitto.log`
10. **healthcheck** = วิธีตรวจว่า Broker "ใช้ได้จริง" ไม่ใช่แค่ "รันอยู่"
    - ทุก 10 วินาที ลอง subscribe topic `$SYS/broker/version` ด้วยรหัสจริง
    - `-C 1` = รอรับ 1 ข้อความแล้วจบ, `-W 5` = รอไม่เกิน 5 วินาที
    - ผ่าน = `healthy`, ล้มเหลว 6 ครั้งติด = `unhealthy`
    - `$$` = เขียน `$` จริง ๆ (เพราะ `$` เดี่ยวใน compose หมายถึงแทนค่าตัวแปร)

> 💡 **ทำไม healthcheck สำคัญ** — รหัสผ่านผิดหรือ ACL ผิด Mosquitto ยัง "รันอยู่"
> แต่ใช้งานไม่ได้ healthcheck ที่ล็อกอินจริงจะจับได้ `run_all.ps1` รอจนเป็น `healthy`

---

## 7. อ่านไฟล์จริง #2: `deploy/backend.Dockerfile` (สูตรสร้าง image ของ Backend)

```dockerfile
FROM node:22-alpine            # (1)

ENV NODE_ENV=production        # (2)
ENV TZ=Asia/Bangkok

WORKDIR /app                   # (3)

COPY package*.json ./          # (4)
RUN npm ci --omit=dev          # (5)

COPY . .                       # (6)

EXPOSE 3000                    # (7)
CMD ["node", "src/server.js"]  # (8)
```

1. เริ่มจาก image ที่มี Node.js 22 บน Alpine Linux (Linux ตัวเล็กมาก ~5 MB)
2. ตั้งตัวแปรในกล่อง: โหมด production, เขตเวลาไทย
3. ย้ายไปทำงานที่โฟลเดอร์ `/app` ในกล่อง (สร้างให้ถ้าไม่มี)
4. คัดลอกเฉพาะ `package.json` กับ `package-lock.json` เข้าไปก่อน
5. ติดตั้งไลบรารี `--omit=dev` = ไม่เอาไลบรารีที่ใช้ตอนพัฒนาเท่านั้น
6. คัดลอกโค้ดที่เหลือทั้งหมดเข้าไป
7. บอกว่ากล่องนี้ใช้พอร์ต 3000 (เป็นเอกสาร ไม่ได้เปิดพอร์ตจริง)
8. คำสั่งที่รันเมื่อกล่องเปิด = `node src/server.js`

> 💡 **ทำไมคัดลอก `package.json` ก่อน แล้วค่อยคัดลอกโค้ด?**
> Docker จำผลของแต่ละบรรทัดไว้ (layer cache) ถ้าแก้แค่โค้ดแต่ `package.json` ไม่เปลี่ยน
> บรรทัด 4–5 ใช้ของเดิมได้ ไม่ต้อง `npm ci` ใหม่ build เร็วขึ้นมาก

ไฟล์ `backend/.dockerignore` บอกว่าไม่ต้องคัดลอกอะไรเข้ากล่อง (เช่น `node_modules`, `.env`)

---

## 8. อ่านไฟล์จริง #3: `deploy/docker-compose.yml` (เซิร์ฟเวอร์จริง 4 กล่อง)

```text
                         อินเทอร์เน็ต
          443/80 (HTTPS)                 8883 (MQTTS)
                │                              │
┌───────────────▼──────────────────────────────▼──────────── docker network ─┐
│  ┌────────────┐   /api/*   ┌─────────────┐  mqtt://mqtt:1883  ┌──────────┐ │
│  │  caddy     │──────────▶│  backend    │───────────────────▶│  mqtt    │ │
│  │  (caddy:2) │ backend:3000│ (Dockerfile)│                    │(mosquitto)│ │
│  └────────────┘            └──────┬──────┘                    └──────────┘ │
│                                   │ db:3306                                │
│                            ┌──────▼──────┐                                 │
│                            │  db         │ ◀── 127.0.0.1:3306 (เฉพาะในเครื่อง)│
│                            │ (mariadb:11)│                                 │
│                            └─────────────┘                                 │
└────────────────────────────────────────────────────────────────────────────┘
```

### จุดสำคัญ: ชื่อ service ใช้เป็นชื่อเครื่องได้

ใน Compose ทุกกล่องอยู่ใน **เครือข่ายภายในเดียวกัน** และเรียกหากันด้วยชื่อ service

```yaml
  backend:
    environment:
      DB_HOST: db                    # ← หมายถึงกล่อง "db"
      MQTT_URL: mqtt://mqtt:1883     # ← หมายถึงกล่อง "mqtt"
```

และใน `Caddyfile`

```text
handle /api/* {
    reverse_proxy backend:3000       # ← หมายถึงกล่อง "backend"
}
```

### ส่วนอื่นที่น่าสนใจ

```yaml
x-logging: &default-logging          # (1) ประกาศค่าที่ใช้ซ้ำ ตั้งชื่อว่า default-logging
  driver: json-file
  options:
    max-size: "10m"                  #     log ไฟล์ละไม่เกิน 10 MB
    max-file: "5"                    #     เก็บ 5 ไฟล์ = รวม 50 MB ต่อกล่อง

services:
  db:
    logging: *default-logging        # (2) ดึงค่าที่ประกาศไว้มาใช้
    ports:
      - "127.0.0.1:3306:3306"        # (3) เข้าได้เฉพาะจากในเซิร์ฟเวอร์เอง
    volumes:
      - ./db/data:/var/lib/mysql     # (4) ข้อมูลอยู่ที่ /opt/rmutt/db/data
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]

  backend:
    build: ./backend                 # (5) สร้าง image เองจาก backend/Dockerfile
    env_file: .env                   # (6) โหลดตัวแปรทั้งไฟล์ .env
    depends_on:
      db:
        condition: service_healthy   # (7) รอ db พร้อมจริงก่อนค่อยเปิด backend
      mqtt:
        condition: service_started
```

1–2. **YAML anchor** (`&ชื่อ`) กับ **alias** (`*ชื่อ`) = เขียนครั้งเดียวใช้หลายที่
3. ป้องกันไม่ให้คนจากอินเทอร์เน็ตต่อฐานข้อมูลตรง
4. **bind mount** = ผูกโฟลเดอร์จริงบนเซิร์ฟเวอร์
5. ไม่ดึง image สำเร็จรูป แต่ build จากโค้ด
6. ตัวแปรลับทั้งหมดมาจาก `/opt/rmutt/.env`
7. ลำดับการเปิด: db → (healthy) → backend → caddy

---

## 9. ไฟล์ YAML อ่านอย่างไร

`docker-compose.yml` เขียนด้วยภาษา **YAML**

```yaml
key: value                  # คู่ ชื่อ: ค่า
parent:                     # object ซ้อน
  child: value              # ย่อหน้าด้วย "ช่องว่าง 2 ตัว" (ห้ามใช้ Tab)
list:                       # รายการ
  - item1
  - item2
text: >-                    # ข้อความยาวหลายบรรทัด (ต่อกันเป็นบรรทัดเดียว)
  บรรทัดหนึ่ง
  บรรทัดสอง
quoted: "1883:1883"         # ใส่ " " เมื่อมีอักขระพิเศษ เช่น :
```

> ⚠️ ข้อผิดพลาดยอดฮิต: ย่อหน้าไม่ตรงกัน หรือใช้ Tab — Docker จะบอก `yaml: line X: ...`

---

## 10. สถานการณ์จริงที่ใช้ Docker ในโปรเจกต์

| อยากทำ | คำสั่ง | รันที่ |
|---|---|---|
| เปิด Mosquitto บนเครื่อง | `.\mqtt\start_mqtt.ps1` หรือ `cd mqtt; docker compose --env-file .env up -d` | Windows |
| ดู log Mosquitto | `docker logs --tail 50 rmutt-mosquitto` | Windows |
| ดักฟังข้อความ MQTT ทั้งหมด | `.\diagnose.ps1` (ขั้น 7) | Windows |
| เปิด MariaDB | `docker start mariadb` | Windows |
| อัปเดต Backend บนเซิร์ฟเวอร์ | `docker compose up -d --build backend` | Linux |
| รัน migration บนเซิร์ฟเวอร์ | `docker compose exec backend npm run db:doctor` | Linux |
| สำรองฐานข้อมูล | `docker compose exec -T db mariadb-dump ...` (อยู่ใน `backup-db.sh`) | Linux |

`-T` ใน `docker compose exec -T` = **ไม่จำลอง terminal** ใช้เมื่อส่งข้อมูลผ่าน pipe `|`
หรือรันจากสคริปต์

---

## 11. สรุปบท

- Image = แม่แบบ, Container = กล่องที่รันอยู่, Volume = ข้อมูลที่อยู่รอด
- `"เครื่องจริง:ในกล่อง"` ใช้ทั้งพอร์ตและโฟลเดอร์
- `docker compose up -d` / `down` / `ps` / `logs -f` / `exec` คือ 5 คำสั่งหลัก
- ใน Compose กล่องเรียกกันด้วยชื่อ service (`db`, `mqtt`, `backend`)
- healthcheck บอกว่ากล่อง "ใช้ได้จริง" (`healthy`)

## 🧪 แบบฝึกหัด

1. รัน `docker ps -a` แล้วอธิบายทุกคอลัมน์
2. เปิด `deploy/docker-compose.yml` แล้วหาว่า Caddy เปิดพอร์ตอะไรบ้าง และทำไม
3. ถ้าแก้ไฟล์ `backend/src/routes/rooms.js` บนเซิร์ฟเวอร์ ต้องสั่งคำสั่งอะไรให้มีผล
   (ตอบ: `docker compose up -d --build backend`)
4. อธิบายว่าทำไม `DB_HOST` บนเครื่องเราคือ `127.0.0.1` แต่บนเซิร์ฟเวอร์คือ `db`
5. `docker compose down` กับ `docker compose stop` ต่างกันอย่างไร

ถัดไป: **บท 06 MQTT และ Mosquitto**
