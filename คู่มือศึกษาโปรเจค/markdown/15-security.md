# ความปลอดภัยทั้งระบบ

## ภาพรวม

บทนี้ไม่ได้อธิบายไฟล์ใดไฟล์หนึ่ง แต่ตัดขวางทั้งระบบเพื่อตอบคำถามที่อาจารย์ถามได้แน่นอนว่า **"ระบบนี้ปลอดภัยแค่ไหน และคุณป้องกันอะไรไว้บ้าง"** วิธีคิดของบทนี้คือเดินไปทีละชั้น (layer) ของระบบ แต่ละชั้นตอบสี่ข้อเหมือนกันหมด

1. **ภัยคุกคาม (threat):** อะไรอาจผิดพลาดหรือใครอาจทำอะไรได้
2. **วิธีป้องกันในโปรเจค:** ไฟล์ไหน บรรทัดไหน ตั้งค่าอะไร
3. **ทำไมทำแบบนี้:** ทางเลือกอื่นคืออะไร และเสียอะไรถ้าไม่ทำ
4. **จุดอ่อนที่ยังเหลือ:** ยังไม่ปลอดภัยตรงไหน และควรปรับปรุงอย่างไร

ระบบนี้มีลักษณะที่ทำให้ความปลอดภัยสำคัญเป็นพิเศษ เพราะมัน **สั่งงานอุปกรณ์ไฟฟ้าจริง** (เปิด/ปิดแอร์ทั้งอาคาร) ไม่ใช่แค่แสดงข้อมูล ถ้าคนร้ายยึดระบบได้ ผลคือแอร์ถูกเปิดทิ้งทั้งคืน หรือถูกปิดกลางคาบเรียน และเซิร์ฟเวอร์ก็ต่ออินเทอร์เน็ตจริงผ่าน Tailscale Funnel จึงเป็นเป้าสแกนของคนทั่วโลกตั้งแต่วันแรก

ภาพคร่าว ๆ ของ "เส้นแบ่งความเชื่อถือ" (trust boundary) ที่บทนี้ใช้เป็นแกน

```text
อินเทอร์เน็ต ─┬─ HTTPS 443 (โดเมน DuckDNS) ──────────┐
              ├─ HTTPS 443 (Tailscale Funnel) ───────┤→ Caddy ─── /api/* → Backend ─→ MariaDB (127.0.0.1 เท่านั้น)
              ├─ MQTTS 8443 (Funnel, บอร์ด ESP32) ─→ tailscale ถอด TLS ─→ :1883 ─┐
              └─ MQTTS 8883 (บอร์ดในอาคาร ต่อตรง) ───────────────────────────────→ Mosquitto ←─ Backend ต่อ mqtt://mqtt:1883 ภายใน docker
มือถือ/เว็บ ──(JWT)──→ API        ESP32 ──(บัญชี MQTT ต่อบอร์ด)──→ Broker      BLE ←→ แอปตอนตั้งค่า
```

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

**CIA triad** คือสามเป้าหมายของความปลอดภัย **C**onfidentiality (ความลับ: คนที่ไม่มีสิทธิ์ต้องอ่านไม่ได้ เช่น รหัสผ่าน), **I**ntegrity (ความถูกต้อง: ข้อมูลและคำสั่งต้องไม่ถูกแก้โดยไม่ได้รับอนุญาต เช่น คำสั่งเปิดแอร์ ไฟล์เฟิร์มแวร์), **A**vailability (ความพร้อมใช้: ระบบต้องใช้งานได้ ไม่ถูกทำให้ล่ม เช่น rate limit กันคนล็อกอินรัว ๆ ทำให้ทุกคนเข้าไม่ได้) ทุกมาตรการในบทนี้ปกป้องอย่างน้อยหนึ่งในสามข้อนี้

**Authentication vs Authorization** *Authentication (ยืนยันตัวตน)* คือ "คุณคือใคร" ในระบบนี้ทำด้วย username+password แล้วได้ JWT ส่วน *Authorization (กำหนดสิทธิ์)* คือ "คุณทำอะไรได้" ในระบบนี้คือ role `admin` กับ `staff` (ตรวจด้วย `requireAdmin`) สองเรื่องนี้แยกกัน คนที่ล็อกอินสำเร็จ (authenticated) ยังไม่ได้แปลว่ามีสิทธิ์ทุกอย่าง (authorized)

**Hashing vs Encryption** *Hash* เป็นทางเดียว แปลงข้อมูลเป็นลายนิ้วมือแล้วย้อนกลับไม่ได้ ใช้เก็บรหัสผ่านเพราะเซิร์ฟเวอร์ไม่จำเป็นต้องรู้รหัสจริง แค่เทียบ hash กัน *Encryption* เป็นสองทาง ถอดรหัสกลับได้ถ้ามีกุญแจ ใช้ตอนต้องอ่านข้อมูลเดิมกลับมา เช่น TLS ที่เข้ารหัสข้อมูลระหว่างทาง ห้ามเก็บรหัสผ่านด้วย encryption เพราะถ้ากุญแจหลุด รหัสผ่านทุกตัวหลุดหมด

**Salt vs Pepper** *Salt* คือค่าสุ่มที่ผสมกับรหัสผ่านก่อน hash และ **เก็บคู่กับ hash ในฐานข้อมูล** ทำให้รหัสเหมือนกันได้ hash ไม่เหมือนกัน และกัน rainbow table (ตาราง hash สำเร็จรูป) bcrypt ฝัง salt ไว้ในสตริงผลลัพธ์เองอยู่แล้ว *Pepper* คือความลับที่ผสมเพิ่มแต่ **เก็บแยกจากฐานข้อมูล** (ในไฟล์ `.env`) ถ้าคนร้ายขโมยฐานข้อมูลไปได้อย่างเดียว ก็ยังเดาค่าที่ hash ไม่ได้เพราะไม่มี pepper

**HMAC** คือ hash ที่ต้องมีกุญแจลับ `HMAC(กุญแจ, ข้อความ)` ใครไม่มีกุญแจคำนวณผลซ้ำไม่ได้ ระบบนี้ใช้ HMAC ในสามที่ คือ hash ของ OTP, hash ของ token และรหัสผ่าน MQTT ของบอร์ด

**MITM (Man-in-the-Middle)** คนที่ดักอยู่กลางทางระหว่างสองฝ่าย แอบอ่านหรือแก้ข้อมูล (เช่น คนที่นั่งใน Wi-Fi เดียวกัน) แก้ด้วย **TLS** ซึ่งเข้ารหัสและพิสูจน์ตัวตนเซิร์ฟเวอร์ด้วยใบรับรอง (certificate) ที่ออกโดย CA ที่ไว้ใจได้

**XSS (Cross-Site Scripting)** คนร้ายแทรก JavaScript เข้าไปในหน้าเว็บ (เช่น ผ่านชื่อวิชาที่มีแท็ก `<script>`) แล้วสคริปต์นั้นรันในเบราว์เซอร์ของเหยื่อ ขโมย token ได้ กันด้วยการไม่เอาข้อมูลดิบไปใส่เป็น HTML และใช้ CSP

**SQL Injection** คนร้ายพิมพ์ SQL ปนมาในช่องกรอก (เช่น `' OR 1=1 --`) ให้ฐานข้อมูลรันคำสั่งที่ไม่ได้ตั้งใจ กันด้วย **parameterized query** (ใส่ `?` แล้วส่งค่าแยก ฐานข้อมูลถือว่าเป็นข้อมูลเสมอ ไม่ใช่คำสั่ง)

**Brute force** เดารหัสผ่านหรือ OTP ซ้ำ ๆ จนถูก กันด้วย rate limit (จำกัดจำนวนครั้ง) และ hash ที่ช้าโดยตั้งใจ (bcrypt)

**Timing attack** วัดเวลาตอบเพื่อเดาข้อมูล เช่น ถ้า "ไม่มี username นี้" ตอบเร็วกว่า "มี username แต่รหัสผิด" คนร้ายก็รู้ว่าชื่อไหนมีจริง แก้ด้วยการทำงานให้เวลาใกล้เคียงกันทุกกรณี

**Least privilege (สิทธิ์น้อยที่สุดที่ทำงานได้)** ให้ทุกส่วนมีสิทธิ์เท่าที่จำเป็นเท่านั้น เช่น บอร์ดแต่ละตัวส่งได้แค่ topic ของตัวเอง Backend ใช้ user ฐานข้อมูลที่ไม่ใช่ root

**Defense in depth (ป้องกันหลายชั้น)** ไม่พึ่งด่านเดียว สมมติว่าด่านใดด่านหนึ่งพังได้ แล้วมีอีกด่านรองรับ เช่น กัน XSS สองชั้น (ไม่ใช้ `innerHTML` กับข้อมูลผู้ใช้ **และ** มี CSP)

**Secret (ความลับ) คืออะไร** ค่าที่ถ้าหลุดแล้วระบบเสียหาย เช่น `JWT_SECRET`, รหัสฐานข้อมูล, token ของ DuckDNS ต้องไม่อยู่ใน git ไม่ฝังในโค้ด และสุ่มให้ยาวพอ

## ชั้นที่ 1: การเปิดพอร์ตและเครือข่าย (network exposure)

**ภัยคุกคาม:** ถ้าฐานข้อมูล, Broker หรือ SSH เปิดสู่อินเทอร์เน็ต คนทั่วโลกจะสแกนเจอและลองเดารหัสภายในไม่กี่นาที พื้นที่โจมตี (attack surface) ยิ่งกว้างยิ่งเสี่ยง

**วิธีป้องกัน:** เปิดเท่าที่จำเป็นและผูกทุกอย่างที่ไม่ต้องเปิดไว้กับ localhost หรือเครือข่ายภายใน docker

| ส่วน | เปิดอย่างไร | ไฟล์ |
|---|---|---|
| MariaDB 3306 | ผูก `127.0.0.1` เท่านั้น เข้าได้จากตัวเซิร์ฟเวอร์เอง ไม่ใช่จากเครือข่าย | `deploy/docker-compose.yml` บรรทัด 29 |
| Mosquitto 8883 | เปิดสู่ภายนอก (TLS) ให้บอร์ดที่ต่อตรงในอาคาร (ทางเลือก) | `deploy/docker-compose.yml` บรรทัด 45 |
| Mosquitto 1883 | **ไม่ publish** เป็นพอร์ตของ container ใช้ในเครือข่าย docker เท่านั้น (Backend ต่อ `mqtt://mqtt:1883` และกล่อง tailscale ส่งต่อพอร์ต 8443 จาก Funnel มาที่นี่) | `docker-compose.yml` (ไม่มีบรรทัด ports ของ 1883) |
| Backend 3000 | **ไม่ publish** ถึงได้ผ่าน Caddy (`/api/*`) เท่านั้น | `docker-compose.yml` (มีแค่ `EXPOSE` ใน Dockerfile) |
| Caddy 80/443 | เปิดสู่ภายนอก (ทางโดเมนหลัก) | `docker-compose.yml` บรรทัด 155–156 |
| Tailscale Funnel | ส่งต่อ 443 ไป `caddy:8080` (เว็บ/API) และ 8443 (ถอด TLS ที่กล่อง tailscale) ไป `mqtt:1883` (MQTT ของบอร์ด) เท่านั้น | `deploy/tailscale-serve.json` บรรทัด 3–7, 16–19 |

**ไฟล์ `deploy/docker-compose.yml` บรรทัด 26–29**

```yaml:26
    # เปิดพอร์ตเฉพาะ localhost ของเซิร์ฟเวอร์เท่านั้น เข้าจากเครือข่ายไม่ได้
    # ใช้ต่อ DBeaver/HeidiSQL ผ่าน SSH tunnel
    ports:
      - "127.0.0.1:3306:3306"
```

คำอธิบาย: `"127.0.0.1:3306:3306"` อ่านว่า `<IP ที่ผูก>:<พอร์ตบนเครื่อง>:<พอร์ตใน container>` ถ้าเขียนแค่ `"3306:3306"` Docker จะผูก `0.0.0.0` คือทุกการ์ดเครือข่าย เปิดให้คนทั้งโลกเห็น การใส่ `127.0.0.1` ทำให้ต่อได้เฉพาะจากเครื่องเซิร์ฟเวอร์เอง ถ้าผู้พัฒนาอยากดูข้อมูลด้วย DBeaver จากเครื่องตัวเอง ใช้ **SSH tunnel** (`db-tunnel.ps1`) คือเปิดท่อเข้ารหัสผ่าน SSH ที่ลงท้ายที่ `127.0.0.1:3306` ของเซิร์ฟเวอร์ ไม่ต้องเปิดพอร์ตฐานข้อมูลสู่อินเทอร์เน็ตเลย `db-tunnel.ps1` ใช้บัญชี `DB_USER` ของแอป (สิทธิ์เฉพาะฐานข้อมูลนี้) ไม่ใช้ root

> [!WHY]
> **ทำไม Funnel ส่งต่อแค่สองปลายทาง คือ `caddy:8080` (พอร์ต 443) และ `mqtt:1883` (พอร์ต 8443)** เซิร์ฟเวอร์อยู่ในเครือข่ายมหาวิทยาลัย (IP 10.x) ที่เปิดพอร์ตขาเข้าไม่ได้ Funnel ให้ container `tailscale` **ต่อออก** ไปหา Tailscale เอง (outbound) แล้วเปิดทางสาธารณะให้ที่ `https://<ชื่อ>.ts.net` จึงไม่ต้องเจาะ firewall ขาเข้า และ `deploy/tailscale-serve.json` กำหนดปลายทางไว้สองจุดเท่านั้น: `"Proxy": "http://caddy:8080"` (พอร์ต 443 เว็บ/API) กับ `"TCPForward": "mqtt:1883"` พร้อม `"TerminateTLS"` (พอร์ต 8443 MQTT ของบอร์ด ทำให้บอร์ดที่ต่อ Wi-Fi นอกมหาวิทยาลัยเข้าถึง Broker ได้) ฐานข้อมูลและ SSH จึงไม่ถูกเปิดผ่านทางนี้ (ดูคอมเมนต์ใน `docker-compose.yml` บรรทัด 172–179) และยัง **ปิดได้ทันที** ด้วย `docker compose stop tailscale` ถ้าเกิดเหตุ นอกจากนี้ container รันโหมด `TS_USERSPACE: "true"` ไม่ต้องการ `NET_ADMIN` หรือ `/dev/net/tun` ไม่แตะเครือข่ายของเครื่อง

> [!WARN]
> พอร์ต 8443 ทำให้ Mosquitto **เข้าถึงได้จากอินเทอร์เน็ต** เป็นครั้งแรก (เดิมต่อได้เฉพาะในเครือข่ายมหาวิทยาลัย) ด่านป้องกันมี 3 ชั้น: (1) TLS ระหว่างบอร์ดกับกล่อง tailscale (2) `allow_anonymous false` + Dynamic Security ต้องมี username/password ของบอร์ด (3) ACL รายบอร์ดจำกัด topic แต่ยังไม่มีการจำกัดอัตราการเชื่อมต่อหรือแบน IP ที่ชั้น MQTT และ Mosquitto เห็นต้นทางทุกคำขอเป็นกล่อง tailscale ช่วงสุดท้ายจากกล่อง tailscale ไป `mqtt:1883` เป็น MQTT ดิบ แต่อยู่ในเครือข่าย docker ของเครื่องเดียว ถ้าบอร์ดทุกตัวอยู่ในอาคาร ให้ตั้ง `MQTT_DEVICE_URL=mqtts://<DOMAIN>:8883` ใน `.env` แล้วเอาพอร์ต 8443 ออกจาก `serve.json` เพื่อลดพื้นผิวโจมตี

**Firewall (`deploy/setup-vps.sh` บรรทัด 69–81):** เมื่อรันด้วย `--firewall` สคริปต์ตั้ง `ufw default deny incoming` แล้วอนุญาตเฉพาะ 22 (SSH), 80, 443 และ 8883 (พอร์ต 443/8443 ของ Funnel ไม่ต้องเปิดใน ufw เพราะเป็นทางที่กล่อง tailscale ต่อออกไปเอง) ส่วนที่ไม่ได้ใช้ `--firewall` เป็นกรณีที่ฝ่ายไอทีมหาวิทยาลัยดูแล firewall อยู่แล้ว สคริปต์ติดตั้ง `fail2ban` (แบน IP ที่เดารหัส SSH ซ้ำ ๆ) ให้ด้วยแต่ **ไม่ได้ตั้งค่าเฉพาะ** ใช้ค่าเริ่มต้นของแพ็กเกจ

> [!NOTE]
> หลักการ "ปฏิเสธทุกอย่างเป็นค่าเริ่มต้น แล้วเปิดเท่าที่จำเป็น" (default deny) คือหัวใจของ firewall ที่ดี และข้อควรรู้: Docker เขียนกฎ iptables เองข้าม `ufw` ได้ ดังนั้น **การผูก `127.0.0.1` ในไฟล์ compose คือด่านจริงของฐานข้อมูล** ห้ามพึ่งแค่ ufw

**จุดอ่อนที่เหลือ:** ไม่มีการตั้งค่า SSH ให้เข้มงวด (เช่นปิดล็อกอินด้วยรหัสผ่านให้ใช้ key อย่างเดียว) สคริปต์ `db-tunnel.ps1` เองยังบอกให้ "พิมพ์รหัส SSH" แปลว่าใช้รหัสผ่านล็อกอินอยู่ และคอมเมนต์ใน `setup-vps.sh` บรรทัด 75 เขียนว่าเปิดพอร์ต 80 เพื่อ "Lets Encrypt" ซึ่งไม่จริงแล้ว เพราะใช้ DNS-01 (ดูหัวข้อ TLS) พอร์ต 80 จึงใช้แค่ redirect เป็น HTTPS

## ชั้นที่ 2: TLS ทุกเส้นทาง

**ภัยคุกคาม:** ถ้าข้อมูลวิ่งเป็นข้อความธรรมดา คนที่อยู่ในเครือข่ายเดียวกันหรือผู้ให้บริการอินเทอร์เน็ตอ่านรหัสผ่าน, JWT และคำสั่งแอร์ได้ (MITM) หรือแก้คำสั่งกลางทางได้

**วิธีป้องกัน:**

| เส้นทาง | ใช้ TLS อย่างไร | ที่ตั้งค่า |
|---|---|---|
| เว็บ/มือถือ → Caddy (โดเมนหลัก) | HTTPS ใบรับรอง Let's Encrypt ที่ Caddy ขอและต่ออายุให้เอง | `deploy/Caddyfile` บรรทัด 66–87 |
| เว็บ/มือถือ → Funnel | HTTPS ใบรับรองของ Tailscale (`*.ts.net`) ถอด TLS ที่ container tailscale แล้วส่ง HTTP ต่อใน docker network | `tailscale-serve.json`, `Caddyfile` บรรทัด 90–93 |
| ESP32 → Funnel 8443 → Mosquitto (ค่าเริ่มต้น) | MQTTS: บอร์ดต่อชื่อ ts.net พอร์ต 8443 ตรวจใบ ts.net (Let's Encrypt) กับ root CA ในเฟิร์มแวร์ กล่อง tailscale ถอด TLS (`TerminateTLS`) แล้วส่ง MQTT ดิบต่อไป `mqtt:1883` ในเครือข่าย docker | `tailscale-serve.json` บรรทัด 4–7, `docker-compose.yml` บรรทัด 113 |
| ESP32 → Mosquitto (ต่อตรง) | MQTTS พอร์ต 8883, `tls_version tlsv1.2` ขึ้นไป (ใช้เมื่อตั้ง `MQTT_DEVICE_URL` เป็นพอร์ต 8883) | `deploy/mosquitto/config/mosquitto.conf` บรรทัด 23–27 |
| ESP32 → ดาวน์โหลดเฟิร์มแวร์ | HTTPS ตรวจใบรับรองกับ root CA ในเฟิร์มแวร์ | `firmware/*/ota_update.h`, `letsencrypt_ca.h` |
| Backend → Mosquitto | `mqtt://mqtt:1883` แบบไม่เข้ารหัส **แต่** อยู่ในเครือข่าย docker ภายในเครื่องเดียว (ช่วงสุดท้ายจากกล่อง tailscale ของทาง Funnel 8443 ก็เป็น MQTT ดิบแบบเดียวกัน) | `docker-compose.yml` บรรทัด 106 |
| Backend → MariaDB | ภายใน docker network เช่นกัน | `docker-compose.yml` บรรทัด 89 |

**ใบรับรองด้วย DuckDNS แบบ DNS-01:** ปกติ Let's Encrypt พิสูจน์ว่าคุณเป็นเจ้าของโดเมนด้วยการเข้ามาที่พอร์ต 80 ของเซิร์ฟเวอร์ (HTTP-01) แต่เซิร์ฟเวอร์นี้อยู่หลังเครือข่ายมหาวิทยาลัย Let's Encrypt เข้ามาไม่ได้ จึงใช้ **DNS-01** คือ Caddy เขียน TXT record ชื่อ `_acme-challenge` ผ่าน API ของ DuckDNS (ใช้ `DUCKDNS_TOKEN`) แล้ว Let's Encrypt ตรวจจาก DNS แทน

**ไฟล์ `deploy/Caddyfile` บรรทัด 71–77**

```text:71
	tls {
		dns duckdns {env.DUCKDNS_TOKEN}
		# DNS ของมหาวิทยาลัยตอบ SERVFAIL ตอนหา zone ของ _acme-challenge จึงถาม DNS สาธารณะแทน
		resolvers 1.1.1.1 8.8.8.8
		propagation_delay 60s
		propagation_timeout -1
	}
```

- `dns duckdns {env.DUCKDNS_TOKEN}`: ใช้ปลั๊กอิน DuckDNS (ติดตั้งใน image ด้วย `xcaddy` ใน `deploy/caddy.Dockerfile`) อ่าน token จากตัวแปรสภาพแวดล้อมของ container ไม่ฝังในไฟล์
- `resolvers 1.1.1.1 8.8.8.8`: ถาม DNS สาธารณะเพราะ DNS ในมหาวิทยาลัยตอบผิด
- `propagation_delay 60s` + `propagation_timeout -1`: รอ 60 วินาทีให้ DNS กระจายแล้วให้ Let's Encrypt ตรวจเลย ไม่ให้เซิร์ฟเวอร์ตรวจ DNS เอง (เครือข่ายอาจบล็อกพอร์ต 53)

ข้อดีเพิ่มเติมของ DNS-01: ไม่ต้องเปิดพอร์ต 80 ให้ Let's Encrypt และ token DuckDNS **ใช้ได้แค่แก้ DNS ของโดเมนตัวเอง** ไม่ใช่สิทธิ์เข้าเซิร์ฟเวอร์

**ใบรับรองสำหรับ Mosquitto:** Mosquitto ไม่ขอใบเอง `deploy/sync-mqtt-cert.sh` (cron รันทุกวัน) คัดลอกใบที่ Caddy ขอได้ไปที่ `mosquitto/certs/` แล้ว reload เฉพาะเมื่อใบเปลี่ยนจริง เพื่อให้ MQTTS ใช้ใบเดียวกับเว็บ

**Root CA ในเฟิร์มแวร์:** ESP32 ไม่มีที่เก็บ CA ของระบบแบบคอมพิวเตอร์ ต้องฝังใบรากไว้ในโค้ด ไฟล์ `firmware/rmutt_esp32_air/letsencrypt_ca.h` (สร้างด้วย `firmware/update-root-ca.ps1`) ฝัง **ISRG Root X1** (RSA, หมดอายุ 2035) และ **Root X2** (ECDSA, หมดอายุ 2040) ไว้ทั้งคู่ เพราะ Let's Encrypt อาจออกใบจากสายใดสายหนึ่ง ถ้าฝังไว้ใบเดียวแล้ววันหนึ่งสลับสาย บอร์ดทุกตัวจะต่อไม่ได้พร้อมกันจนกว่าจะแฟลชใหม่ ในโค้ดบอร์ดเรียก `secureClient.setCACert(LETSENCRYPT_CA)` (`rmutt_esp32_air.ino` บรรทัด 1057) แปลว่า **ตรวจใบรับรองจริง** ไม่ได้ปิดการตรวจ (ไม่มี `setInsecure()` ในโค้ด) และเพราะใบรับรองมีวันหมดอายุ บอร์ดต้อง **ซิงก์เวลา NTP ให้ได้ก่อน** (`ensureClockSynced()`) ถึงจะตรวจได้ ถ้าเวลาผิด TLS จะล้มเหลวและบอร์ดไม่ต่อ (ล้มแบบปลอดภัย) ใบ ts.net ที่กล่อง tailscale ใช้ถอด TLS ที่พอร์ต 8443 ออกโดย Let's Encrypt เช่นกัน จึงตรวจผ่านด้วยใบรากชุดเดียวกันโดยไม่ต้องแก้เฟิร์มแวร์

**HSTS:** `Strict-Transport-Security "max-age=31536000"` (Caddyfile บรรทัด 22) สั่งเบราว์เซอร์จำว่าโดเมนนี้ต้องใช้ HTTPS เท่านั้นเป็นเวลา 1 ปี ป้องกันการถูกลดระดับเป็น HTTP (SSL stripping)

**จุดอ่อนที่เหลือ:** ไม่มี certificate pinning ในแอปมือถือ (แอปเชื่อ CA ของระบบปฏิบัติการ) ถ้า CA ใด ๆ ถูกหลอกให้ออกใบปลอมก็ดักได้ในทางทฤษฎี, HSTS ไม่มี `includeSubDomains`/`preload`, และ MQTT ภายใน docker เป็นข้อความธรรมดา (ยอมรับได้เพราะอยู่เครื่องเดียวกัน แต่ถ้าย้าย Backend ไปคนละเครื่องต้องเปลี่ยนเป็น TLS)

## ชั้นที่ 3: เว็บ (webapp)

**ภัยคุกคาม:** (1) XSS แทรกสคริปต์แล้วขโมย token (2) clickjacking (ฝังเว็บเราใน iframe ของเว็บร้ายแล้วหลอกให้กดปุ่ม) (3) ถูกหลอกให้เว็บส่งรหัสผ่านไปยัง API ปลอม (4) เบราว์เซอร์เดาประเภทไฟล์ผิด

**วิธีป้องกัน: security headers ใน Caddy** ทั้งโดเมนหลักและ Funnel ใช้บล็อก `(app)` ร่วมกัน (`deploy/Caddyfile` บรรทัด 10–27) จึงได้หัวเดียวกันทั้งสองทาง

**ไฟล์ `deploy/Caddyfile` บรรทัด 20–27**

```text:20
	header {
		Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'"
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "camera=(), microphone=(), geolocation=()"
		-Server
	}
```

| หัว / คำสั่ง | ความหมาย | กันอะไร |
|---|---|---|
| `script-src 'self'` | รันสคริปต์ได้เฉพาะไฟล์ `.js` จากโดเมนเราเท่านั้น ห้าม inline `<script>` และ `eval` | XSS (แม้มีคนแทรก `<script>` ก็ไม่รัน) |
| `connect-src 'self'` | `fetch`/XHR ไปได้เฉพาะโดเมนเรา | สคริปต์แปลกปลอมส่ง token ออกไปเว็บอื่นไม่ได้ |
| `frame-ancestors 'none'` | ห้ามใครฝังหน้าเราใน iframe | clickjacking |
| `object-src 'none'`, `base-uri 'self'`, `form-action 'self'` | ปิด plugin, ห้ามเปลี่ยน base URL, ห้ามฟอร์มส่งออกนอกโดเมน | การแทรก `<base>`/ฟอร์มปลอม |
| `style-src ... 'unsafe-inline'` | ยอม inline style เพราะหน้าเว็บใช้ `style=""` ในบางจุด | (ผ่อนปรนโดยรู้ตัว ความเสี่ยงต่ำ ดูคอมเมนต์ในไฟล์) |
| `X-Content-Type-Options: nosniff` | เบราว์เซอร์ห้ามเดาประเภทไฟล์เอง | ไฟล์ที่ถูกตีความเป็นสคริปต์ |
| `Referrer-Policy` | ไม่ส่ง URL เต็มไปเว็บอื่นตอนกดลิงก์ออก | URL รั่ว |
| `Permissions-Policy` | ปิดกล้อง ไมค์ ตำแหน่ง | เว็บ/สคริปต์ขอสิทธิ์ที่ไม่จำเป็น |
| `-Server` | ลบหัว `Server: Caddy` ออก | บอกรุ่นซอฟต์แวร์ให้คนสแกน |

ฝั่ง API ก็มีหัวของตัวเองด้วย `app.use(helmet())` และ `app.disable('x-powered-by')` (`backend/src/app.js` บรรทัด 28, 34) helmet ใส่หัวความปลอดภัยพื้นฐานชุดหนึ่งให้ทุก response ของ Express ซ้อนกับของ Caddy อีกชั้น

**การหลีกเลี่ยง XSS ในโค้ด DOM:** `webapp/assets/js/dom.js` เป็นตัวช่วยสร้าง element (`el()`) ที่ **ใส่ข้อความด้วย `textContent` หรือ `createTextNode` เสมอ** ไม่เอาข้อความไปต่อสตริง HTML ดังนั้นชื่อวิชา ชื่ออาจารย์ หรือชื่อห้องที่มีอักขระ `<` `>` จึงแสดงเป็นตัวหนังสือธรรมดา ไม่ถูกตีความเป็นแท็ก คำสั่ง `innerHTML` ถูกใช้เฉพาะกับไอคอน SVG ที่ระบบเขียนเอง (เช่น `icons.menu(18)`) ไม่ใช่ข้อมูลจากผู้ใช้ ตรวจได้ด้วยการค้นหา `html:` และ `innerHTML` ใน `webapp/assets/js` จะพบว่าทุกจุดรับค่าจากฟังก์ชันไอคอนหรือสตริง SVG ที่เขียนตายตัว

> [!WHY]
> **ทำไมทำสองชั้น (XSS defense in depth)** ชั้นแรก (ไม่ใช้ `innerHTML` กับข้อมูลผู้ใช้) กันที่ต้นเหตุ ชั้นที่สอง (CSP) กันตอนชั้นแรกพลาด เช่นวันหนึ่งนักพัฒนาลืมแล้วใช้ `innerHTML` กับชื่อวิชา CSP ยังไม่ยอมรัน inline script และไม่ยอมให้ส่งข้อมูลออกนอกโดเมน เหตุผลที่ต้องกังวลเป็นพิเศษ คือเว็บเก็บ token ไว้ใน `localStorage` ซึ่ง JavaScript ทุกตัวในหน้าอ่านได้

**`?api=` ใช้ได้เฉพาะ localhost:** `webapp/assets/js/config.js` ตอนพัฒนาให้เปิด `http://127.0.0.1:5500/?api=http://127.0.0.1:3000/api` เพื่อชี้ไป Backend บนเครื่องตัวเองได้ แต่ถ้าโค้ดรับพารามิเตอร์นี้บนโดเมนจริง คนร้ายก็ส่งลิงก์ `https://ระบบจริง/?api=https://เว็บร้าย` แล้วเบราว์เซอร์เหยื่อจะจำค่านั้นใน `localStorage` และส่ง username/password ไปเว็บร้ายทุกครั้งที่ล็อกอิน (phishing ที่มาจากโดเมนจริง)

**ไฟล์ `webapp/assets/js/config.js` บรรทัด 40–46**

```js:40
function resolveApiBase() {
  try {
    if (!isLocalPage()) {
      // ล้างค่าที่อาจถูกฝังไว้จากลิงก์แปลก ๆ ก่อนหน้านี้ แล้วใช้ API ของโดเมนนี้เสมอ
      window.localStorage.removeItem(STORAGE_API);
      return '/api';
    }
```

- `isLocalPage()` (บรรทัด 20–22) ตรวจว่า `window.location.hostname` อยู่ในชุด `localhost`, `127.0.0.1`, `[::1]`, `::1` หรือไม่
- ถ้า **ไม่ใช่** หน้าบนเครื่องตัวเอง: **ลบ** ค่า `rmutt.apiBase` เก่าที่อาจถูกฝังไว้ แล้วคืน `'/api'` (path บนโดเมนเดียวกัน) ทันที ไม่อ่าน query string เลย
- `normalizeApiBase` (บรรทัด 25–38) รับเฉพาะ path ที่ขึ้นต้นด้วย `/` (แต่ไม่ใช่ `//` ซึ่งเป็น protocol-relative URL ไปโดเมนอื่น) หรือ URL แบบ `http:`/`https:` เท่านั้น ปฏิเสธ `javascript:` และอื่น ๆ

**Token ใน localStorage (trade-off):** `webapp/assets/js/api.js` เก็บ JWT ใน `localStorage` (คีย์ `rmutt.token`) และแนบด้วยหัว `Authorization: Bearer ...` เหตุผลที่ไม่ใช้ cookie (อธิบายใน `auth.js` หัวไฟล์): Backend ตรวจสิทธิ์จากหัว Authorization อย่างเดียว ถ้าใช้ cookie ต้องคิดเรื่อง **CSRF** (เว็บร้ายหลอกเบราว์เซอร์ให้ส่ง cookie ของเราไปยิง API) เพิ่มโดยไม่ได้ประโยชน์

| | localStorage + Bearer (ที่ใช้) | cookie `HttpOnly` |
|---|---|---|
| อ่านด้วย JS (ขโมยตอนมี XSS) | **อ่านได้** (จุดอ่อน) | อ่านไม่ได้ |
| CSRF | ไม่เกิด เพราะเบราว์เซอร์ไม่แนบ header เอง | เกิดได้ ต้องมี CSRF token / SameSite |
| ใช้กับแอปมือถือเดียวกัน | ใช้ได้เหมือนกัน | ยุ่งกว่า |

ระบบจึงเลือกรับความเสี่ยง XSS แล้ว **ลดด้วย CSP + ไม่ใช้ innerHTML** แทน และอายุ token สั้น (8 ชั่วโมง) ส่วนแอปมือถือเก็บ token ด้วย `flutter_secure_storage` (`lib/services/auth_service.dart` บรรทัด 5, 32) ซึ่งใช้ที่เก็บที่ระบบปฏิบัติการปกป้อง (Android Keystore) ปลอดภัยกว่า localStorage

อีกเรื่องที่ทำไว้ดี: ตอนแรกแอปจำรหัสผ่านไว้ใน secure storage ปัจจุบัน `loadRememberedLogin()` (บรรทัด 47–54) **ลบรหัสผ่านที่รุ่นเก่าเคยเก็บทิ้งทุกครั้ง** และจำแค่ username ส่วนการอยู่ในระบบต่อใช้ token ที่หมดอายุเองและเพิกถอนได้จากเซิร์ฟเวอร์

**จุดอ่อนที่เหลือ:** CSP ยอม `'unsafe-inline'` ใน style, โหลดฟอนต์จาก Google Fonts (มีคำขอไปบุคคลที่สาม), และ token ใน `localStorage` ยังเสี่ยงถ้ามีช่องโหว่ XSS สักจุดที่หลุดทั้งสองชั้น

## ชั้นที่ 4: API (Backend)

### 4.1 JWT และการยืนยันตัวตน

**ภัยคุกคาม:** ปลอม token, ใช้ token เก่าหลังเปลี่ยนรหัสผ่านหรือโดนปิดบัญชี, แก้ role ใน token ให้เป็น admin

**ตอนออก token** (`backend/src/routes/auth.js` บรรทัด 89–102)

```js:89
    const token = jwt.sign(
      {
        role: user.role,
        ver: Number(user.token_version),
      },
      config.jwtSecret,
      {
        algorithm: 'HS256',
        subject: user.username,
        expiresIn: config.jwtExpiresIn,
        issuer: 'rmutt-save-energy-api',
        audience: 'rmutt-save-energy-app',
      },
    );
```

| Claim | ค่า | หน้าที่ |
|---|---|---|
| `sub` | username | ตัวตนเจ้าของ token |
| `exp` | `JWT_EXPIRES_IN` (ค่าเริ่มต้น `8h`, `config.js` บรรทัด 43) | หมดอายุเอง ลดความเสียหายถ้า token หลุด |
| `iss` / `aud` | `rmutt-save-energy-api` / `rmutt-save-energy-app` | กัน token ของระบบอื่นที่ใช้ secret เดียวกันมาใช้ที่นี่ |
| `role` | admin/staff | ใส่ไว้เพื่อให้ฝั่ง client อ่านเร็ว ๆ แต่ **Backend ไม่เชื่อค่านี้** |
| `ver` | `token_version` ในตาราง `users` | ใช้เพิกถอน token (อธิบายด้านล่าง) |
| `algorithm: 'HS256'` | HMAC-SHA256 ใช้กุญแจลับตัวเดียวทั้งเซ็นและตรวจ | |

**ตอนตรวจ token ทุกคำขอ** (`backend/src/middleware/authenticate.js` บรรทัด 16–38)

```js:16
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, {
      algorithms: ['HS256'],
      issuer: 'rmutt-save-energy-api',
      audience: 'rmutt-save-energy-app',
    });
  } catch {
    throw new ApiError(401, 'รหัสเข้าสู่ระบบหมดอายุหรือไม่ถูกต้อง');
  }

  const rows = await pool.query(
    `SELECT username, first_name, last_name, email, phone, role,
            token_version
       FROM users
      WHERE username = ? AND is_active = 1
      LIMIT 1`,
    [payload.sub],
  );
  const user = rows[0];

  if (!user || Number(user.token_version) !== Number(payload.ver)) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบใหม่');
  }
```

- `algorithms: ['HS256']` **ระบุอัลกอริทึมที่ยอมรับเอง** ไม่ให้ไลบรารีเชื่อ header `alg` ในตัว token ปิดช่องโจมตีแบบ `alg: none` (token ไม่เซ็น) และการสลับอัลกอริทึม
- `jwt.verify` ตรวจลายเซ็น วันหมดอายุ `exp` `iss` และ `aud` ให้ในคำสั่งเดียว ล้มเหลวอย่างไรก็ตอบ 401 ข้อความกลาง ๆ ไม่บอกว่าผิดเพราะอะไร
- **อ่าน user จากฐานข้อมูลทุกคำขอ** (`WHERE username = ? AND is_active = 1`) แล้วใช้ `role` จากแถวในฐานข้อมูล (ผ่าน `request.authUser = publicUser(user)` บรรทัด 41) **ไม่ใช้ `role` ใน token** ดังนั้นถ้าคนร้ายได้ token ของ staff ไป ก็แก้เป็น admin เองไม่ได้ (ลายเซ็นไม่ผ่าน) และถ้า admin ลดสิทธิ์ใครก็มีผลทันที
- เทียบ `token_version` ในฐานข้อมูลกับ `ver` ใน token ถ้าไม่เท่ากัน = token ถูกเพิกถอนแล้ว `token_version` ถูกบวกเพิ่ม (`token_version + 1`) ใน 4 กรณี คือ เปลี่ยนรหัสผ่านเอง (`auth.js` บรรทัด 229–236), รีเซ็ตรหัสผ่านด้วย OTP (บรรทัด 405–412), admin เปลี่ยน role/สถานะผู้ใช้ (`routes/users.js` บรรทัด 122–128) และรัน `seed-admin`

> [!WHY]
> **ทำไมยอมเสียค่า query ฐานข้อมูลทุกคำขอ** JWT ปกติเป็น stateless (ไม่ต้องถามฐานข้อมูล) เร็วแต่ **เพิกถอนไม่ได้จนกว่าจะหมดอายุ** ถ้าบัญชีถูกปิดหรือรหัสผ่านถูกขโมยแล้วเปลี่ยน token เก่ายังใช้ได้อีกเป็นชั่วโมง ที่นี่ผู้ใช้หลักหลายสิบคน ภาระ query เล็กน้อยเทียบกับ "ปิดบัญชีแล้วมีผลทันที" คุ้มกว่า เป็นการแลกความเร็วกับความปลอดภัย

**Authorization:** `requireAdmin` (`backend/src/middleware/require-admin.js` บรรทัด 3–12) ตรวจ `request.authUser?.role !== 'admin'` แล้วตอบ 403 ใช้ต่อท้าย `authenticate` เสมอ (ลำดับ: ยืนยันตัวตนก่อน แล้วค่อยตรวจสิทธิ์) บาง router ใช้ทั้งไฟล์ เช่น `usersRouter.use(requireAdmin)` และ `firmwareRouter.use(authenticate, requireAdmin)` บาง router ใส่เป็นรายเส้นทาง เช่น `POST /api/air-conditioners/reservations`, `/:deviceId/setup-mode`, `/:deviceId/ota`

### 4.2 Rate limit (จำกัดจำนวนครั้ง)

ทั้งหมดอยู่ใน `backend/src/routes/auth.js` (ไม่มี rate limit ที่เส้นทางอื่น) ใช้ไลบรารี `express-rate-limit`

| ตัวจำกัด | ใช้กับ | จำนวน | ช่วงเวลา | หมายเหตุ |
|---|---|---|---|---|
| `loginLimiter` (บรรทัด 27–33) | `POST /login` | 10 ครั้ง | 15 นาที | นับต่อ IP ทุกคำขอ |
| `passwordConfirmLimiter` (บรรทัด 37–44) | `PATCH /me`, `POST /me/password` | 10 ครั้ง | 15 นาที | `skipSuccessfulRequests: true` นับเฉพาะครั้งที่ **ผิด** |
| `resetLimiter` (บรรทัด 46–52) | `POST /forgot-password`, `/verify-otp`, `/reset-password` | 8 ครั้ง | 1 ชั่วโมง | ตัวนับ **ร่วมกัน** ทั้งสามเส้นทาง เพราะใช้ตัวจำกัดตัวเดียวกัน |

เมื่อเกิน ตอบ 429 พร้อมข้อความไทย และ `standardHeaders: 'draft-7'` ส่งหัว `RateLimit-*` ให้ client รู้โควตา

**TRUST_PROXY=2 และเหตุผล:** Rate limit ต้องรู้ "IP จริงของผู้ใช้" แต่เมื่อมี reverse proxy คั่น Backend จะเห็นแค่ IP ของ proxy ต้องอ่านจากหัว `X-Forwarded-For` (XFF) ซึ่ง **ปลอมได้ถ้าเชื่อมั่ว** ๆ

| เส้นทาง | ลำดับ | จำนวนชั้นที่ Backend ต้องเชื่อ |
|---|---|---|
| โดเมนหลัก | ผู้ใช้ → Caddy → Backend | 1 |
| Funnel | ผู้ใช้ → Tailscale → Caddy (`:8080`) → Backend | 2 |

ใช้เส้นทางเดียวกันทั้งสองทาง จึงตั้งเป็น **2** (`docker-compose.yml` บรรทัด 85) ถ้าตั้งเป็น 1 ทุกคนที่เข้าผ่าน Funnel (รวมแอปมือถือทั้งหมด) จะถูกนับเป็น IP เดียวกัน ใครพิมพ์รหัสผิด 10 ครั้ง ทุกคนล็อกอินไม่ได้ 15 นาที (ตัวอย่าง "ทำให้ระบบใช้ไม่ได้" ที่เป็นปัญหา Availability) ส่วนการปลอม XFF: ทางโดเมนหลัก Caddy ทิ้ง XFF ที่ผู้ใช้ส่งมาเองและเขียนใหม่ ส่วนที่ `:8080` มี `trusted_proxies static private_ranges` (`Caddyfile` บรรทัด 3–7) แปลว่าเชื่อ XFF เฉพาะจากต้นทางที่อยู่ในวงเครือข่ายส่วนตัว (container tailscale)

**ไฟล์ `backend/src/config.js` บรรทัด 12–19**

```js:12
function trustProxyFromEnv(name) {
  const raw = (process.env[name] ?? '').trim();
  if (raw === '' || raw.toLowerCase() === 'false') return false;
  if (/^\d+$/.test(raw)) return Number.parseInt(raw, 10);
  // ค่า true จะทำให้ใครก็ปลอม IP ได้ และ express-rate-limit จะปฏิเสธ
  if (raw.toLowerCase() === 'true') return 1;
  return raw;
}
```

ค่าว่าง = `false` (ไม่เชื่อ XFF เลย เหมาะกับรันตรงบนเครื่อง) ตัวเลข = เชื่อกี่ชั้น และถ้าใส่ `true` จะถูกแปลงเป็น 1 แทน เพราะ `true` แปลว่าเชื่อ **ทุกชั้นรวมที่ผู้ใช้ส่งมาเอง** อันตราย

### 4.3 การตรวจข้อมูลขาเข้า, SQL, และการตอบ error

- **Parameterized SQL ทั้งระบบ** ทุก query ใช้ `?` และส่งค่าเป็นอาร์เรย์ เช่น `WHERE username = ? ... [payload.sub]` ส่วนที่มีการต่อสตริง SQL (`${...}`) ตรวจแล้วเป็นส่วนที่โค้ดกำหนดเอง ไม่ใช่ข้อมูลผู้ใช้ เช่น รายการคอลัมน์ที่ `PATCH /air-conditioners/:deviceId` ประกอบจาก `fields.push('auto_off_attempts = 0')` (ข้อความคงที่ทั้งหมด) และ `keyExpression` ใน `routes/energy.js` ที่เลือกจากสองสตริงคงที่ ตามค่า `granularity` ที่ผ่านการตรวจแล้ว
- **Validate ก่อนใช้:** `validateDeviceId` ใช้ regex `^ESP32-[0-9A-F]{12}$` (`utils/air-conditioner.js` บรรทัด 4, 137–143) ชื่อห้องใช้ `^[A-Z0-9][A-Z0-9_-]{1,19}$` เวลาใช้ `^(?:[01]\d|2[0-3]):[0-5]\d$` โหมดแอร์/ความเร็วพัดลม/โปรโตคอลตรวจกับ `Set` ของค่าที่ยอมรับ (`modes`, `fanSpeeds`, `protocols`) แปลว่าสิ่งที่ไม่อยู่ในรายการถูกปฏิเสธ (allowlist ปลอดภัยกว่า blocklist) อีกที่คือ `cleanString(value, maxLength)` ใน `auth.js` บรรทัด 423–426 ตัดความยาวและรับเฉพาะ string
- **จำกัดขนาด:** `express.json({ limit: '256kb' })` (`app.js` บรรทัด 36) กันคนส่ง JSON ก้อนยักษ์ให้หน่วยความจำเต็ม เกินแล้วตอบ 413 และรหัสผ่านที่ login ยาวเกิน 256 ตัวถูกปฏิเสธ (`auth.js` บรรทัด 63)
- **Error ไม่รั่วข้อมูลภายใน:** `errorHandler` (`utils/http.js` บรรทัด 19–40) แยกสามแบบ คือ `ApiError` (ข้อความที่เราตั้งใจให้ผู้ใช้เห็น) 413 และอย่างอื่นทั้งหมด (เช่น ฐานข้อมูลล่ม โค้ดมีบั๊ก) ตอบแค่ `เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์` พร้อม status 500 โดย `console.error(error)` ลง log ฝั่งเซิร์ฟเวอร์เท่านั้น ไม่ส่ง stack trace หรือข้อความ SQL ให้ client
- **ข้อความ login กลาง ๆ:** ทั้งกรณีไม่มี username และรหัสผิดตอบ `Username หรือ Password ไม่ถูกต้อง` เหมือนกัน (บรรทัด 81) และหน้า forgot-password ตอบข้อความเดียวกันไม่ว่าบัญชีมีหรือไม่ (บรรทัด 300–304) เพื่อไม่ให้คนร้ายใช้เป็นเครื่องเดาว่า username ไหนมีในระบบ (user enumeration)

**`/api/health` ซ่อนรายละเอียดบน production** (`app.js` บรรทัด 38–59): เส้นทางนี้ไม่ต้องล็อกอิน (Docker healthcheck และเครื่องมือเรียกใช้) จึงต้องไม่บอกข้อมูลที่ช่วยโจมตี ถ้า `config.env === 'production'` ตอบแค่ `connected`, `deviceAuth`, `topicPrefix` ไม่บอกที่อยู่ Broker หรือข้อความ error ภายใน (ตอนพัฒนาบนเครื่องได้รายละเอียดเต็มให้ `check_system.ps1` ใช้ตรวจ)

**CORS:** `createCorsOptions()` (`app.js` บรรทัด 77–98) บนเซิร์ฟเวอร์จริง `APP_ORIGIN` เป็นรายการที่อนุญาต (`https://${DOMAIN},${PUBLIC_URL:-}` ใน compose บรรทัด 88) ถ้า `Origin` ไม่อยู่ในรายการ → error ส่วนคำขอที่ไม่มี `Origin` (แอปมือถือ, curl) ผ่านได้ เพราะ CORS เป็นกลไกของ **เบราว์เซอร์** ไม่ใช่การยืนยันตัวตน ค่าเริ่มต้นในโค้ดเป็น `*` (สะดวกตอนพัฒนา) เปลี่ยนเป็นรายการจริงโดย `docker-compose.yml`

**ตรวจ secret ตอนเริ่มเซิร์ฟเวอร์:** `assertServerConfig()` (`config.js` บรรทัด 74–126) เรียกใน `server.js` บรรทัด 11 ก่อนเริ่มรับคำขอ ถ้า `JWT_SECRET`/`OTP_PEPPER` สั้นกว่า 32 ตัวหรือมีคำว่า `replace|change|example` (ค่าตัวอย่างจาก `.env.example` ที่ลืมเปลี่ยน) เซิร์ฟเวอร์ **ไม่ยอมเริ่ม** (fail closed)

**ไฟล์ `backend/src/config.js` บรรทัด 137–139**

```js:137
function unsafeSecret(value) {
  return value.length < 32 || /replace|change|example/i.test(value);
}
```

## ชั้นที่ 5: รหัสผ่านและ OTP

### 5.1 รหัสผ่าน: bcryptjs cost 12 + dummy hash

**ภัยคุกคาม:** ฐานข้อมูลรั่ว → ถ้าเก็บรหัสผ่านจริงหรือ hash เร็ว ๆ (MD5/SHA) คนร้ายเดาได้เป็นพันล้านครั้งต่อวินาทีด้วย GPU

**วิธีป้องกัน:** ใช้ `bcryptjs` ด้วย cost 12 (`bcrypt.hash(newPassword, 12)` ใน `auth.js` บรรทัด 235, 379 และ `scripts/seed-admin.js`) bcrypt ช้าโดยตั้งใจ (cost 12 = ทำซ้ำ 2^12 รอบ ใช้เวลาระดับหลักร้อยมิลลิวินาทีต่อครั้ง) ทำให้การเดารหัสแพงมาก และมี salt สุ่มฝังในผลลัพธ์ (`$2b$12$<salt><hash>`) อยู่แล้ว ข้อจำกัดคือ bcrypt อ่านรหัสแค่ **72 ไบต์แรก** `isValidNewPassword` (`utils/security.js` บรรทัด 23–29) จึงบังคับ 8 ตัวขึ้นไป และไม่เกิน 72 ไบต์ (ตัวอักษรไทยกินตัวละ 3 ไบต์ ดูเทสต์ใน `test/security.test.js`) ไม่งั้นส่วนที่เกินจะถูกทิ้งเงียบ ๆ

**Dummy hash กัน timing attack** (`auth.js` บรรทัด 24–25, 76–82)

```js:76
    const isCorrect = user
      ? await bcrypt.compare(password, user.password_hash)
      : await bcrypt.compare(password, dummyPasswordHash);

    if (!user || !isCorrect) {
      throw new ApiError(401, 'Username หรือ Password ไม่ถูกต้อง');
    }
```

ปัญหา: `bcrypt.compare` ใช้เวลานาน (หลักร้อย ms) ถ้าไม่มี user แล้วข้ามไปตอบทันที จะเร็วกว่ากรณีมี user อย่างเห็นได้ชัด คนร้ายจับเวลาแล้วรู้ว่า username ไหนมีจริง วิธีแก้คือ **ถ้าไม่พบ user ก็ยังเปรียบเทียบกับ hash ปลอม** (`dummyPasswordHash` ซึ่งเป็น bcrypt cost 12 ที่ไม่ตรงรหัสผ่านใดเลย) เพื่อให้ใช้เวลาใกล้เคียงกัน ผลลัพธ์ที่ได้ไม่ถูกใช้ (ผ่านเงื่อนไข `!user` อยู่แล้ว) แค่ "เผาเวลา" เท่ากัน

**ปกป้องการแก้ข้อมูลสำคัญ:** `PATCH /me` ถ้า **เปลี่ยนอีเมล** ต้องส่ง `currentPassword` ถูกต้อง (บรรทัด 135–156) เพราะ OTP ลืมรหัสผ่านถูกส่งไปที่อีเมลนั้น ถ้าไม่บังคับ คนที่ได้เครื่องที่ลืมล็อกเอาท์จะเปลี่ยนอีเมลเป็นของตัวเองแล้วกด "ลืมรหัสผ่าน" ยึดบัญชีถาวรได้ และ `/me/password` ต้องใช้รหัสเดิม รหัสใหม่ต้องไม่ซ้ำเดิม และทั้งสองใช้ `passwordConfirmLimiter` นับเฉพาะครั้งที่ผิด

**ผู้ดูแลคนสุดท้าย:** `assertAnotherActiveAdminExists` (`routes/users.js` บรรทัด 174–189) ไม่ยอมให้ลบ/ปิด/ลดสิทธิ์ admin คนสุดท้าย (409) กันระบบไม่มีใครดูแล (Availability) และใช้ `SELECT ... FOR UPDATE` ใน transaction กัน race condition สองคนลบกันพร้อมกัน

### 5.2 OTP ลืมรหัสผ่าน: HMAC + pepper, หมดอายุ, จำกัดครั้ง, reset token

โฟลว์ 3 ขั้น: `forgot-password` (สร้าง OTP ส่งอีเมล) → `verify-otp` (ตรวจ OTP ได้ reset token) → `reset-password` (ตั้งรหัสใหม่)

**ไฟล์ `backend/src/utils/security.js` บรรทัด 5–21**

```js:5
export function createOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

export function createResetToken() {
  return crypto.randomBytes(32).toString('hex');
}

export function hashSecret(value, pepper = config.otpPepper) {
  return crypto.createHmac('sha256', pepper).update(value).digest('hex');
}

export function safeHashEquals(leftHash, rightHash) {
  const left = Buffer.from(leftHash, 'hex');
  const right = Buffer.from(rightHash, 'hex');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}
```

| ฟังก์ชัน | ทำอะไร | ทำไม |
|---|---|---|
| `createOtp` | เลข 6 หลัก `100000–999999` ด้วย `crypto.randomInt` | ใช้ตัวสุ่มระดับความปลอดภัย (CSPRNG) ไม่ใช่ `Math.random()` ซึ่งเดาได้ |
| `createResetToken` | สุ่ม 32 ไบต์ = 64 ตัว hex (256 บิต) | เดาไม่ได้ในทางปฏิบัติ |
| `hashSecret` | **HMAC-SHA256** โดยใช้ `OTP_PEPPER` เป็นกุญแจ | ดูด้านล่าง |
| `safeHashEquals` | เทียบแบบ `timingSafeEqual` | เทียบแบบ `===` จะหยุดทันทีที่พบไบต์ต่าง เวลาตอบจึงบอกใบ้ว่าตรงไปกี่ไบต์ ส่วนนี้ใช้เวลาเท่ากันเสมอ |

> [!WHY]
> **ทำไม OTP ใช้ HMAC+pepper ไม่ใช้ bcrypt** OTP มีแค่ 10^6 แบบ (หนึ่งล้าน) ต่อให้ใช้ SHA-256 ธรรมดา คนที่ขโมยตาราง `password_reset_otps` ไปคำนวณครบล้านแบบได้ในเสี้ยววินาที แต่ HMAC ต้องใช้ `OTP_PEPPER` ซึ่งอยู่ใน `.env` ไม่ได้อยู่ในฐานข้อมูล ขโมยฐานข้อมูลอย่างเดียวจึงถอด OTP ไม่ได้ ส่วนรหัสผ่านใช้ bcrypt เพราะอยู่ถาวรและต้องทนการเดาออฟไลน์ ส่วน OTP อายุสั้นและมีจำกัดครั้ง ใช้ HMAC พอและเร็วกว่า

**ขั้นตอนกำกับความปลอดภัย:**

1. `forgot-password`: สร้าง OTP, **ทำเครื่องหมาย OTP เก่าของบัญชีเดียวกันว่าใช้แล้ว** (`SET used_at = NOW() WHERE username = ? AND used_at IS NULL`, บรรทัด 269–274) ให้มี OTP ที่ใช้ได้ครั้งละอันเดียว เก็บเฉพาะ **hash** (`otp_hash`) ไม่เก็บ OTP จริง `expires_at` = ตอนนี้ + `OTP_EXPIRES_MINUTES` (ค่าเริ่มต้น 10 นาที) ส่งอีเมล ถ้าส่งไม่สำเร็จจะลบแถวนั้นทิ้ง
2. `verify-otp` (บรรทัด 308–360): ตรวจรูปแบบ `requestId` (UUID) และ OTP (`/^\d{6}$/`) ปฏิเสธถ้าไม่มีแถว/ใช้แล้ว/`attempts >= 5`/หมดอายุ ด้วยข้อความเดียวกัน (`OTP ไม่ถูกต้องหรือหมดอายุแล้ว`) ถ้า OTP ผิดจะ `attempts + 1` และถูกได้แค่ **5 ครั้งต่อคำขอหนึ่ง** ถ้าถูกจะออก reset token (ส่งกลับให้ผู้ใช้ **เก็บเฉพาะ hash** ลง `reset_token_hash`)
3. `reset-password` (บรรทัด 362–421): ตรวจ reset token (64 hex), hash แล้วหาแถว (`FOR UPDATE` ล็อกแถวใน transaction), ต้อง `verified_at` มีค่า, ยังไม่ `used_at`, ยังไม่หมดอายุ แล้วจึงเปลี่ยนรหัสผ่าน **บวก `token_version`** (ทุกอุปกรณ์ที่ล็อกอินค้างต้องเข้าใหม่) และตั้ง `used_at` (ใช้ซ้ำไม่ได้)

คำนวณความเสี่ยงการเดา: ต่อ OTP หนึ่งอัน เดาได้ 5 ครั้งจาก 1,000,000 → โอกาส 0.0005% และการขอ OTP ใหม่ต้องผ่าน `resetLimiter` (8 ครั้ง/ชม. รวมทุกเส้นทาง) จึงเดาต่อเนื่องไม่ได้

**จุดอ่อนที่เหลือ:** หน้า `forgot-password` ตอบเหมือนกันทุกกรณีก็จริง แต่ถ้ามีบัญชี โค้ดต้องเขียนฐานข้อมูลและ **รอส่งอีเมล (SMTP) จนเสร็จ** ก่อนตอบ (บรรทัด 261–298) ส่วนไม่มีบัญชีตอบทันที จึงมี timing channel ให้ใช้เดาได้ว่า username/อีเมลมีหรือไม่ ปรับปรุงได้โดยส่งอีเมลแบบ background (ไม่ `await`) หรือหน่วงเวลาให้เท่ากัน

## ชั้นที่ 6: MQTT

**ภัยคุกคาม:** ใครต่อ Broker ได้ก็อาจ (1) สั่งแอร์ทุกห้องผ่าน topic `.../command` (2) ส่งข้อมูลค่าไฟปลอม (3) แอบอ่านสถานะ ถ้ารหัสผ่านร่วมกันทุกบอร์ด **แค่ถอดบอร์ดเดียวออกมาอ่านรหัสใน flash ก็สั่งแอร์ได้ทั้งอาคาร** (ตามที่คอมเมนต์ใน `utils/mqtt-accounts.js` บรรทัด 3–5 เล่าไว้ว่าเป็นดีไซน์เก่าที่ถูกเปลี่ยน)

**วิธีป้องกัน:**

**(ก) ไม่ยอมให้ anonymous:** `deploy/mosquitto/config/mosquitto.conf` บรรทัด 12–13

```ini:12
per_listener_settings false
allow_anonymous false
```

`allow_anonymous false` = ทุกคนต้องมี username/password และ `per_listener_settings false` ทำให้กติกาเดียวกันมีผลกับทุก listener (1883 และ 8883) ไม่มีช่องทางหลบ (รวมถึงทาง Funnel 8443 ซึ่งเข้ามาที่ listener 1883)

**(ข) Dynamic Security: บัญชีและ ACL ต่อบอร์ด** Mosquitto Dynamic Security plugin (บรรทัด 15–16 ของ conf) เก็บบัญชี/role/ACL ในไฟล์ `mosquitto/data/dynamic-security.json` และให้ Backend สร้างบัญชีผ่าน topic `$CONTROL/dynamic-security/v1` ได้ขณะรัน (ไม่ต้อง restart Broker) บอร์ดแต่ละตัวได้ username = Device ID (เช่น `ESP32-AABBCCDDEEFF`) และ role ของตัวเอง

**ไฟล์ `backend/src/utils/mqtt-accounts.js` บรรทัด 20–33 และ 70–86**

```js:20
export const DEVICE_KINDS = {
  air: {
    pattern: /^ESP32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-',
    publish: ['state', 'status', 'provision', 'provision-ack', 'history'],
    subscribe: ['command', 'provision-ack', 'schedule-status', 'history-ack'],
  },
  occupancy: {
    pattern: /^OCC32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-occ-',
    publish: ['status', 'provision', 'provision-ack'],
    subscribe: ['command', 'provision-ack'],
  },
};
```

```js:70
export function deviceAcls({ kind, topicPrefix, deviceId }) {
  const spec = DEVICE_KINDS[kind];
  if (!spec) throw new Error(`Unknown device kind: ${kind}`);
  const base = `${String(topicPrefix).replace(/\/+$/, '')}/${deviceId}`;
  return [
    ...spec.publish.map((suffix) => ({
      acltype: 'publishClientSend',
      topic: `${base}/${suffix}`,
      allow: true,
    })),
    ...spec.subscribe.map((suffix) => ({
      acltype: 'subscribeLiteral',
      topic: `${base}/${suffix}`,
      allow: true,
    })),
  ];
}
```

- บอร์ดแอร์ **publish ได้** เฉพาะ `rmutt/ac/<DeviceID>/{state,status,provision,provision-ack,history}` และ **subscribe ได้** เฉพาะ `.../{command,provision-ack,schedule-status,history-ack}` ของตัวเอง
- `subscribeLiteral` = ต้องตรงชื่อเป๊ะ ไม่ใช้ wildcard (`#`, `+`) จึงเอา topic ของห้องอื่นมาแอบฟังไม่ได้
- ไม่มี ACL ให้ publish ที่ `.../command` เลย แปลว่า **บอร์ดสั่งแอร์ห้องอื่นไม่ได้** (หรือแม้แต่สั่งตัวเอง) คำสั่งส่งได้เฉพาะ Backend ซึ่งเป็นด่านที่ตรวจ JWT/role ก่อน ส่วน topic อื่นทั้งหมดถูกปฏิเสธเป็นค่าเริ่มต้นของ Dynamic Security (default deny)
- Backend มี role `rmutt-backend` (`backendAcls`, บรรทัด 88–98) ได้ publish/subscribe `rmutt/ac/#` และ `rmutt/occupancy/#`

**(ค) รหัสผ่าน = HMAC ของ Device ID** (`utils/mqtt-accounts.js` บรรทัด 44–51)

```js:44
export function deriveDevicePassword(secret, deviceId) {
  if (!secret) throw new Error('MQTT_DEVICE_SECRET is required');
  return crypto
    .createHmac('sha256', secret)
    .update(`mqtt-device:${String(deviceId).trim().toUpperCase()}`)
    .digest('base64url')
    .slice(0, 32);
}
```

รหัสผ่านของบอร์ดแต่ละตัวคือ `HMAC-SHA256(MQTT_DEVICE_SECRET, "mqtt-device:<DeviceID>")` ตัดเหลือ 32 ตัวอักษร base64url ข้อดี: (1) **ไม่ต้องเก็บรหัสในฐานข้อมูล** คำนวณซ้ำได้เสมอ (2) ตั้งค่าบอร์ดซ้ำกี่ครั้งก็ได้รหัสเดิม บอร์ดที่ออนไลน์อยู่จึงไม่หลุด (3) บอร์ดแต่ละตัวรหัสต่างกัน (4) ถ้าบอร์ดหนึ่งถูกเจาะ ได้แค่รหัสของบอร์ดนั้น คำนวณของตัวอื่นไม่ได้เพราะไม่มี `MQTT_DEVICE_SECRET` ข้อเสียที่ต้องรู้: ถ้า `MQTT_DEVICE_SECRET` หลุด ปลอมรหัสของทุกบอร์ดได้ และถ้าเปลี่ยน secret ต้องตั้งค่ารหัสใหม่ให้ทุกบอร์ด

**(ง) วงจรชีวิตของบัญชีบอร์ด** (`backend/src/services/mqtt-accounts.js`): `prepareDeviceCredentials` สร้างบัญชีบน Broker ตอนจองช่อง (`POST /air-conditioners/reservations`) **ก่อน** เขียนฐานข้อมูล (ถ้า Broker ไม่พร้อมจะไม่ทิ้งแถวจองค้าง) `removeDeviceAccount` ลบบัญชีตอนถอดอุปกรณ์ และ `reconcileAccounts` ทุกครั้งที่ Backend ต่อ Broker ได้ จะสร้างบัญชีของบอร์ดทุกตัวในฐานข้อมูลคืนให้ (ถ้าไฟล์ `dynamic-security.json` หายหรือย้ายเซิร์ฟเวอร์ ไม่ต้องตั้งค่าบอร์ดใหม่)

**(จ) บัญชีของ Backend:** สร้างโดย `init-env.sh` (`mosquitto_ctrl dynsec init ... "$MQTT_USERNAME" "$MQTT_PASSWORD"`) ชื่อ `rmutt_backend` รหัสสุ่ม 32 ตัว ไฟล์ `dynamic-security.json` ตั้ง `chmod 600` และ `chown` เป็น uid 1883 (ผู้ใช้ของ mosquitto ใน container)

**จุดอ่อนที่เหลือ (MQTT):**
- ค่าเริ่มต้นในโค้ด `normalizeDeviceAuthMode` คือ `shared` (ทุกบอร์ดใช้บัญชีเดียวกับ Backend) ถ้าลืมตั้ง `MQTT_DEVICE_AUTH=dynsec` ระบบถอยไปโหมดที่อ่อนกว่า **เงียบ ๆ** (มีแค่ `console.warn` ตอน production ใน `config.js` บรรทัด 116–120) ที่ปลอดภัยกว่า (fail closed) คือบังคับ `dynsec` เมื่อ `NODE_ENV=production`
- บัญชีที่ Backend ใช้ถูกสร้างด้วย `dynsec init` ซึ่งเป็นผู้ดูแล Dynamic Security ไปในตัว ถ้า Backend ถูกเจาะ ก็คุม Broker ได้ทั้งหมด (ยอมรับได้เพราะ Backend คือผู้ควบคุมระบบอยู่แล้ว แต่ควรแยกบัญชีผู้ดูแลออกจากบัญชีที่ใช้ publish ทุกวัน)
- Container `mqtt` ได้ `MQTT_USERNAME`/`MQTT_PASSWORD` ของ Backend เป็น env เพื่อใช้ใน healthcheck (`docker-compose.yml` บรรทัด 47–48) ซึ่งเกินความจำเป็นเล็กน้อย
- **Broker เข้าถึงได้จากอินเทอร์เน็ตผ่าน Funnel 8443:** ค่าเริ่มต้นใหม่ของ `MQTT_DEVICE_URL` ทำให้ใครก็ต่อ `ts.net:8443` ได้ ด่านที่มี: TLS, `allow_anonymous false`, บัญชี dynsec รายบอร์ดที่รหัสเป็น HMAC (เดาในทางปฏิบัติไม่ได้), ACL รายบอร์ด ส่วนที่ไม่มี: rate limit/lockout ต่อ IP ที่ Mosquitto (เห็นต้นทางเป็นกล่อง tailscale ทุกคำขอ) จึงยังถูกยิงการเชื่อมต่อถี่ ๆ เพื่อกินทรัพยากรหรือทำ log รกได้ และช่วงจากกล่อง tailscale ไป `mqtt:1883` เป็น MQTT ดิบ (ในเครื่องเดียวกัน) ทางลดความเสี่ยง: ตั้ง `MQTT_DEVICE_URL=mqtts://<DOMAIN>:8883` เมื่อบอร์ดทั้งหมดอยู่ในอาคาร แล้วถอดพอร์ต 8443 ออกจาก `serve.json`

## ชั้นที่ 7: อุปกรณ์ ESP32 และ BLE

### 7.1 Provisioning token (ผูกบอร์ดกับห้อง)

**ภัยคุกคาม:** ใครสักคนส่งข้อความ "ฉันคือบอร์ดห้อง 503" เพื่อให้ระบบรับบอร์ดปลอมเข้ามาในห้องนั้น

**วิธีป้องกัน:** ตอน admin จองช่อง (`POST /api/air-conditioners/reservations`, `requireAdmin`) Backend สร้าง token แบบสุ่ม แล้วเก็บ **เฉพาะ hash** หมดอายุใน 15 นาที (`routes/air-conditioners.js` บรรทัด 145–147, 173, 204)

```js:145
    const token = crypto.randomBytes(24).toString('base64url');
    const mqttTopic = `${config.mqtt.topicPrefix}/${input.deviceId}`;
    const tokenHash = hashSecret(token, config.otpPepper);
```

token ยาว 24 ไบต์ (192 บิต) ส่งให้แอปมือถือหนึ่งครั้งในผลของคำขอ (`expiresInSeconds: 900`) แอปส่งต่อให้บอร์ดทาง BLE บอร์ดส่ง token มาทาง MQTT (`.../provision`) และ Backend ตรวจใน `activateProvisioning` (`services/mqtt.js` บรรทัด 738–788)

- ค้นแถวที่ `provision_status IN ('reserved','active')` และ `provisioning_expires_at > CURRENT_TIMESTAMP` เท่านั้น (หมดอายุแล้วไม่ผ่านแม้ token ถูก)
- hash ที่บอร์ดส่งมาด้วย `hashSecret(token, config.otpPepper)` แล้วเทียบด้วย `safeHashEquals` (เวลาคงที่)
- สำเร็จแล้วเปลี่ยนเป็น `active` และ **ตั้ง `provisioning_token_hash = NULL`** ใช้ซ้ำไม่ได้ (one-time token)

### 7.2 โหมดตั้งค่า BLE: กู้ Wi-Fi เปลี่ยนได้แค่ Wi-Fi

**ภัยคุกคาม:** บอร์ดที่ตั้งค่าแล้วเมื่อ Wi-Fi หลุดจะเปิด BLE รอให้แก้ ใครยืนอยู่ใกล้ก็เชื่อมต่อ BLE ได้ ถ้ายอมให้แก้ได้ทุกช่อง คนแปลกหน้าจะชี้บอร์ดไปหา MQTT Broker ของตัวเองแล้วสั่งแอร์ห้องนั้นได้

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 811–850**

```cpp:811
void enterBleRecovery(const String &reason, bool retryWifi) {
  Serial.printf("Mode: BLE recovery - %s\n", reason.c_str());
  oledReason = reason.length() > 25 ? reason.substring(0, 25) : reason;
  bleBlocksNormalOperation = true;
  onlineSetupExpiresAt = 0;
  wifiRecoveryActive = retryWifi;
  // บอร์ดที่ตั้งค่าแล้วแต่ Wi-Fi หลุด: ใครอยู่ใกล้ก็ต่อ BLE ได้ จึงล็อกห้องและเซิร์ฟเวอร์ไว้
  // ส่วนกรณียังไม่เคยตั้งค่า หรือกด BOOT ค้าง (ต้องเข้าถึงตัวบอร์ด) แก้ได้ทุกช่อง
  bleWifiOnlyMode = retryWifi && config.configured;
```

```cpp:841
bool keepsServerAssignment(const DeviceConfig &incoming) {
  return incoming.roomNumber == config.roomNumber &&
         incoming.airNumber == config.airNumber &&
         incoming.mqttHost == config.mqttHost &&
         incoming.mqttPort == config.mqttPort &&
         incoming.mqttTls == config.mqttTls &&
         incoming.mqttUsername == config.mqttUsername &&
         incoming.mqttPassword == config.mqttPassword &&
         incoming.mqttTopic == config.mqttTopic;
}
```

- `bleWifiOnlyMode = retryWifi && config.configured` เปิดเมื่อ "บอร์ดตั้งค่าแล้ว และเข้าโหมดกู้เพราะ Wi-Fi หลุด"
- ใน `processPendingConfig` (บรรทัด 914) ถ้า `bleWifiOnlyMode && !keepsServerAssignment(incoming)` → ปฏิเสธด้วยรหัส `wifi_only_mode` (ห้อง, เลขแอร์, host/port/TLS/user/password/topic ของ MQTT ต้องตรงของเดิมทั้งหมด) เปลี่ยนได้เฉพาะ SSID/รหัส Wi-Fi
- กรณีที่ **ต้อง** เข้าถึงตัวบอร์ดจริง (ยังไม่เคยตั้งค่า หรือกดปุ่ม BOOT ค้างตอนรีเซ็ต GPIO0) ถือว่าเจ้าของอยู่หน้าเครื่อง ให้แก้ได้ทุกช่อง

### 7.3 โหมดตั้งค่าออนไลน์: เฉพาะแอดมิน และจำกัด 5 นาที

คำสั่ง `enter_setup` ส่งได้ทาง `POST /api/air-conditioners/:deviceId/setup-mode` ซึ่งเป็น `requireAdmin` เท่านั้น Backend ส่งทาง MQTT ซึ่งมีแต่ Backend เท่านั้นที่ publish topic `command` ได้ บอร์ดเปิด BLE ตามคำสั่งแล้วตั้ง `onlineSetupExpiresAt = millis() + ONLINE_SETUP_WINDOW_MS` โดย `ONLINE_SETUP_WINDOW_MS = 5UL * 60UL * 1000UL` (บรรทัด 57) คือ **5 นาที** แล้วปิด BLE เอง และขณะนั้นค่าเดิม (Wi-Fi/MQTT) ยังใช้งานต่อได้จนกว่าจะกดบันทึก

### 7.4 OTA ผ่าน HTTPS แต่ไม่มี signature

**ไฟล์ `firmware/rmutt_esp32_air/ota_update.h` บรรทัด 26–39**

```cpp:26
inline bool otaUrlAllowed(const String &url, const String &host) {
  if (host.isEmpty() || url.length() > OTA_MAX_URL_LENGTH) return false;
  const String prefix = "https://" + host + "/firmware/";
  if (!url.startsWith(prefix) || !url.endsWith(".bin")) return false;
  if (url.indexOf("..") >= 0) return false;
  for (size_t index = prefix.length(); index < url.length(); index++) {
    const char c = url.charAt(index);
    const bool ok = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9') || c == '.' || c == '_' ||
                    c == '-';
    if (!ok) return false;
  }
  return true;
}
```

ป้องกันสามชั้น (ตามคอมเมนต์หัวไฟล์): (1) คำสั่งมาจาก topic `command` ที่มีแต่ Backend ส่งได้ (2) URL ต้องขึ้นต้น `https://<MQTT host ของบอร์ดเอง>/firmware/` ลงท้าย `.bin` ห้ามมี `..` และอักขระต้องเป็นตัวอักษร/ตัวเลข/`. _ -` เท่านั้น ชี้ไปเซิร์ฟเวอร์อื่นหรือเดินออกนอกโฟลเดอร์ไม่ได้ (3) ตรวจใบรับรอง HTTPS กับ root CA ที่ฝังไว้ (`client.setCACert(caCert)` ใน `runHttpsOta`) และไม่ตามการ redirect (`HTTPC_DISABLE_FOLLOW_REDIRECTS`) ฝั่ง Backend `POST /:deviceId/ota` เป็น `requireAdmin` ตรวจชื่อไฟล์ด้วย `validateFirmwareFileName` ตรวจว่ามีไฟล์จริง ตรวจว่าชนิดไฟล์ตรงกับชนิดบอร์ดด้วย `assertFirmwareKind` (เพิ่ม 14 ต.ค. 2569: บอร์ดสายแอร์ `DAIKIN_WIRED` รับเฉพาะไฟล์ `wired`/`slm8` บอร์ด IR รับเฉพาะไฟล์ IR เซ็นเซอร์รับเฉพาะไฟล์ `occ`) และบันทึก log `[ota] <บอร์ด> <- <url> โดย <ผู้สั่ง>` ไว้ตรวจสอบย้อนหลัง

**จุดอ่อนที่เหลือ:** ความแท้ของไฟล์พึ่ง "ใครวางไฟล์ในโฟลเดอร์ `/opt/rmutt/firmware` บนเซิร์ฟเวอร์ได้" เท่านั้น (ตั้งแต่ 14 ต.ค. 2569 มีสองทาง คือ SSH/`scp` และบัญชีแอดมินในเว็บผ่าน `POST /api/firmware` ดูหัวข้อ 7.5) ไม่มี **การเซ็นเฟิร์มแวร์ (code signing)** ไม่มี **secure boot / flash encryption** และไม่มี **rollback** (ค้นหา `esp_ota_mark_app_valid`, `rollback` ในโฟลเดอร์ `firmware/` ไม่พบ) ถ้าเฟิร์มแวร์เสียแต่ดาวน์โหลดครบ บอร์ดจะสลับไปใช้และอาจบูตไม่ขึ้น ถ้าเซิร์ฟเวอร์ถูกเจาะ คนร้ายวาง `.bin` อันตรายแล้วสั่งอัปเดตได้ ปรับปรุงได้ด้วยการเซ็นไฟล์ (เช่น ESP-IDF signed OTA ด้วยคีย์ที่เก็บนอกเซิร์ฟเวอร์), เปิด `CONFIG_APP_ROLLBACK_ENABLE` และเรียก `esp_ota_mark_app_valid_cancel_rollback()` หลังบูตสำเร็จ

อีกประเด็น: เส้นทาง `/firmware/*` ใน Caddy (บรรทัด 35–39) **เปิดสาธารณะ ไม่ต้องล็อกอิน** (ทั้งทางโดเมนหลักและทาง Funnel 443 เพราะใช้บล็อก `(app)` ร่วมกัน และเป็นทางที่บอร์ดซึ่งใช้ชื่อ ts.net ดาวน์โหลด OTA) เพราะบอร์ดไม่มี JWT (จำเป็นต้องเป็นแบบนี้ถ้าไม่เพิ่มกลไกยืนยันตัวบอร์ด) ใครรู้ชื่อไฟล์ดาวน์โหลดเฟิร์มแวร์ไปศึกษาได้ ข้อมูลลับต้องไม่ฝังในไฟล์ `.bin` (ระบบนี้เก็บ Wi-Fi/รหัส MQTT ใน NVS ไม่ใช่ในโค้ด จึงไม่รั่วทางนี้)

**จุดอ่อนที่เหลือของ BLE (ตรวจจากโค้ด):** ใน `startBleProvisioning()` (บรรทัด 666–740) characteristic สำหรับเขียนค่าตั้ง (`CONFIG_UUID`) เป็นแค่ `PROPERTY_WRITE` ไม่มีการตั้ง pairing/bonding/encryption ใด ๆ (ไม่พบ `setSecurityCallbacks`, `setEncryptionLevel` ในโค้ด) ผลคือ (1) ระหว่างหน้าต่างตั้งค่า 5 นาทีของโหมดออนไลน์ ใครอยู่ในระยะ BLE ก็เชื่อมต่อได้ และเนื่องจาก `bleWifiOnlyMode = false` ในโหมดนี้ จึงเขียนได้ทุกช่อง (บอร์ดตรวจแค่ว่า `deviceId` ตรงและ token ไม่ว่าง ส่วนความถูกต้องของ token ตรวจที่ Backend ภายหลัง) (2) ข้อมูลที่แอปส่งผ่าน BLE ตอนตั้งค่า (รหัส Wi-Fi และรหัส MQTT ของบอร์ด) วิ่งบนลิงก์ที่ไม่ได้เข้ารหัสในชั้นแอป ถูกดักได้ถ้ามีคนอยู่ใกล้ตอนตั้งค่า ข้อมูลที่อ่านออกจากบอร์ดผ่าน BLE ไม่รวมรหัส (มีแค่ `hasWifiPassword`/`hasMqttPassword` เป็น true/false) แต่เปิดเผย SSID, MQTT host/username และ Device ID

### 7.5 อัปโหลดเฟิร์มแวร์จากเว็บ: ด่านตรวจก่อนเขียนลงดิสก์ (เพิ่ม 14 ต.ค. 2569)

**ภัยคุกคาม:** เส้น `POST /api/firmware` ให้ผู้ใช้ส่งไฟล์มาเขียนลงดิสก์ของเซิร์ฟเวอร์ ซึ่งเป็นช่องทางคลาสสิกของการโจมตี เช่น ตั้งชื่อไฟล์เป็น `../../app/src/server.js` เพื่อเขียนทับโค้ด (path traversal), ส่งไฟล์ใหญ่มากให้ดิสก์เต็ม, หรือวางไฟล์ที่ไม่ใช่เฟิร์มแวร์ให้บอร์ดดาวน์โหลด และอีกภัยที่ไม่ได้ตั้งใจ คือแอดมินลากไฟล์ผิดชนิดแล้วสั่งบอร์ด ทำให้บอร์ดรีบูตเข้าโปรแกรมของบอร์ดอีกชนิดแล้วใช้งานไม่ได้ (Availability)

**วิธีป้องกัน (ตรวจตามลำดับในโค้ด):**

| ด่าน | ตรวจอะไร | ผิดแล้ว | ไฟล์ |
|---|---|---|---|
| 1. สิทธิ์ | `firmwareRouter.use(authenticate, requireAdmin)` คลุมทั้ง router รวมเส้นอัปโหลดและลบ | 401 / 403 | `routes/firmware.js` บรรทัด 23 |
| 2. ขนาดก่อนอ่าน | `express.raw({ limit: FIRMWARE_MAX_BYTES + 1024 })` Express หยุดอ่าน body ที่ใหญ่เกิน ไม่โหลดเข้าหน่วยความจำทั้งก้อน | 413 | `routes/firmware.js` บรรทัด 47 |
| 3. ชื่อไฟล์ | `validateFirmwareFileName`: regex `^[A-Za-z0-9][A-Za-z0-9._-]{0,118}\.bin$` (ไม่มี `/` ขึ้นต้นด้วยจุดไม่ได้ ลงท้าย `.bin`) และห้ามมี `..` ชื่อที่ถอด percent-encoding ไม่ได้กลายเป็น `''` ซึ่งไม่ผ่าน | 400 | `utils/firmware.js` บรรทัด 5–16, `routes/firmware.js` บรรทัด 130–136 |
| 4. ชนิดตรงแท็บ | `?kind=` ต้องเท่ากับ `firmwareKindOf(ชื่อ)` (`occ` / `wired`,`slm8` / ที่เหลือ = `air`) | 400 | `routes/firmware.js` บรรทัด 58–67 |
| 5. เนื้อไฟล์ | `validateFirmwareImage`: ไม่ว่าง, ไม่เกิน `0x1F0000` ไบต์ (ขนาดช่องโปรแกรมใน `partitions.csv`), ยาว ≥ 256 ไบต์ และไบต์แรกเป็น magic byte `0xE9` ของ ESP image | 400 / 413 | `utils/firmware.js` บรรทัด 100–124 |
| 6. ไม่ทับโดยไม่ตั้งใจ | มีไฟล์ชื่อเดิมแล้วต้องส่ง `?replace=1` | 409 | `routes/firmware.js` บรรทัด 71–76 |
| 7. เขียนแบบ atomic | เขียน `<ชื่อ>.<pid>.part` แล้ว `rename` บอร์ดที่ดาวน์โหลดอยู่ไม่เจอไฟล์ครึ่ง ๆ ล้มกลางทางลบไฟล์ชั่วคราวทิ้ง | 500 (ข้อความบอกให้ตรวจสิทธิ์/`:ro`) | `routes/firmware.js` บรรทัด 81–95 |
| 8. ร่องรอย | log `[firmware] อัปโหลด <ชื่อ> (<ขนาด> bytes) โดย <ผู้ใช้>` และ `[firmware] ลบ ... โดย ...` | - | `routes/firmware.js` บรรทัด 97–100, 125 |
| 9. ตอนสั่งบอร์ด | `assertFirmwareKind(ไฟล์, ชนิดบอร์ด)` ใน route OTA ของแอร์และเซ็นเซอร์ | 400 | `routes/air-conditioners.js` บรรทัด 384, `routes/occupancy-sensors.js` บรรทัด 252 |

> [!WHY]
> ทำไมด่านชื่อไฟล์คือด่านที่สำคัญที่สุด: `path.join(config.firmwareDir, fileName)` จะยอมต่อ `..` ให้ออกนอกโฟลเดอร์ได้ ถ้าชื่อไม่ถูกตรวจ แต่ regex ห้ามทั้ง `/` และ `..` ไว้แล้ว ชื่อที่ผ่านจึงเป็นได้แค่ไฟล์ในโฟลเดอร์ firmware เท่านั้น และเพราะใช้ allowlist (บอกว่าอักขระไหน "ใช้ได้") แทน blocklist (ไล่ห้ามอักขระอันตราย) จึงไม่ต้องตามทันทุกเทคนิค เช่น `%2e%2e` หรือ backslash

> [!NOTE]
> การเช็กไบต์ `0xE9` และขนาดเป็น **การตรวจรูปแบบ ไม่ใช่การยืนยันความแท้** ไฟล์อันตรายที่คอมไพล์เป็นโปรแกรม ESP32 ก็ขึ้นต้นด้วย `0xE9` เหมือนกัน ด่านเหล่านี้จึงกัน "ความผิดพลาด" และไฟล์มั่ว ๆ ได้ แต่ไม่ได้แทน code signing (จุดอ่อนข้อ 1 ยังอยู่) ไฟล์ที่อัปโหลดไม่ถูกรันบนเซิร์ฟเวอร์ แค่ถูก Caddy เสิร์ฟให้บอร์ดดาวน์โหลด

**ความเสี่ยงใหม่ที่มากับฟีเจอร์นี้ (บอกตรง ๆ):**

- **บัญชีแอดมินเว็บกลายเป็นกุญแจของเฟิร์มแวร์** เดิมต้องมี SSH เข้าเซิร์ฟเวอร์ถึงจะวางไฟล์ได้ ตอนนี้แค่รหัสแอดมินในเว็บก็อัปโหลดไฟล์แล้วสั่ง OTA ทุกบอร์ดได้ ความแข็งแรงของรหัสแอดมินและ rate limit ล็อกอินจึงสำคัญขึ้น
- **Backend เขียนโฟลเดอร์ firmware ได้แล้ว** `docker-compose.yml` เปลี่ยน mount ของ Backend จาก `./firmware:/firmware:ro` เป็น `./firmware:/firmware` (บรรทัด 126) และโฟลเดอร์บนเครื่องต้องเป็นของ uid 1000 ถ้า Backend ถูกยึด คนร้ายเปลี่ยนไฟล์ `.bin` ได้ (เดิมทำไม่ได้) ส่วน Caddy ยัง mount แบบ `:ro` เหมือนเดิม (บรรทัด 166)
- **ไม่มีโควตาจำนวนไฟล์** แอดมินอัปโหลดได้เรื่อย ๆ ไฟล์ละไม่เกิน 1,984 KB ดิสก์เต็มได้ถ้าตั้งใจ (ต้องเป็นแอดมินจึงความเสี่ยงต่ำ) ลบไฟล์เก่าได้ด้วย `DELETE /api/firmware/:fileName`

### 7.6 ล้างค่าในบอร์ดเมื่อลบอุปกรณ์ (unprovision, เพิ่ม 13 ต.ค. 2569)

**ภัยคุกคาม:** ก่อนหน้านี้ ลบอุปกรณ์ในแอปลบแค่แถวในฐานข้อมูล บัญชี MQTT และ retained message ตัวบอร์ดยังจำ SSID/รหัส Wi-Fi, ที่อยู่ Broker, username/รหัส MQTT ของตัวเอง และห้องไว้ใน NVS ถ้าบอร์ดถูกถอดไปใช้ที่อื่น ทิ้ง หรือหาย ใครได้ไปก็อ่าน flash เอารหัส Wi-Fi ของอาคารได้ (Confidentiality) นี่คือปัญหา **data hygiene** (การไม่ทิ้งข้อมูลลับค้างไว้ในอุปกรณ์ที่เลิกใช้)

**วิธีป้องกัน:** route ลบ (`DELETE /api/air-conditioners/:deviceId` และ `/api/occupancy-sensors/:deviceId`, `requireAdmin`) เรียก `unprovisionDevice` ส่ง `{"action":"unprovision","deviceId":...}` ไปที่ topic `command` ของบอร์ด บอร์ดที่ได้รับ:

1. ตรวจ `deviceId` ในคำสั่งว่าตรงกับตัวเอง ไม่ตรงไม่ทำ (กันข้อความหลงผิด topic)
2. ตอบ `{"unprovisioned":true,"online":false,"deviceId":...}` ทาง `status` แล้วล้าง retained `status`/`state` ของตัวเอง และตัดการเชื่อมต่อแบบปกติ (ไม่เกิด Last Will)
3. `preferences.clear()` ล้าง NVS ทั้ง namespace ของการตั้งค่า (Wi-Fi, MQTT, ห้อง) และสถานะแอร์ แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธเหมือนบอร์ดใหม่ (`unprovisionAndRestart` ใน `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1174 เป็นต้นไป บอร์ดสายแอร์และเซ็นเซอร์มีฟังก์ชันชื่อเดียวกัน)

Backend รอคำตอบไม่เกิน 4 วินาที แล้วค่อยล้าง retained และ **ลบบัญชี MQTT เป็นขั้นสุดท้าย** (ถ้าลบบัญชีก่อน Broker จะตัดบอร์ดทันทีและคำสั่งล้างค่าไปไม่ถึง) ผลถูกส่งกลับในฟิลด์ `boardCleared` และ log `boardCleared=true/false`

> [!WHY]
> ทำไมคำสั่งต้องมีทั้ง ACL และ `deviceId` ในตัว: คำสั่งนี้ทำลายการตั้งค่า (destructive) ถ้าส่งผิดบอร์ดคือห้องนั้นใช้งานไม่ได้จนกว่าจะมีคนไปตั้งค่าใหม่ ACL ของ Broker ทำให้มีแต่ Backend ที่ publish `command` ได้ และบอร์ดเห็นเฉพาะ topic ตัวเอง การใส่ `deviceId` ซ้ำในเนื้อข้อความเป็นชั้นที่สอง (defense in depth) และไม่ส่งแบบ retain เพราะคำสั่งค้างบน Broker จะล้างบอร์ดรหัสเดิมที่ถูกเพิ่มกลับมาภายหลัง

**จุดอ่อนที่เหลือ:**

- **บอร์ดที่ออฟไลน์ตอนกดลบ ไม่ถูกล้าง** (`boardCleared: false`) รหัส Wi-Fi ยังอยู่ใน flash ผู้ดูแลต้องล้างที่ตัวบอร์ดเอง (ตั้งค่าใหม่ผ่านบลูทูธหรือแฟลชใหม่) ส่วนบัญชี MQTT ถูกลบแล้ว บอร์ดจึงต่อ Broker ไม่ได้อีก (รหัส MQTT ที่ค้างในบอร์ดไร้ประโยชน์)
- **NVS ไม่ได้เข้ารหัส** (ไม่มี flash encryption ดูจุดอ่อนข้อ 1) ระหว่างที่บอร์ดยังใช้งาน ใครถอดบอร์ดไปอ่าน flash ได้ก็ได้รหัส Wi-Fi และรหัส MQTT ของบอร์ดตัวนั้น unprovision ช่วยเฉพาะตอนเลิกใช้
- `preferences.clear()` ลบค่าในระดับ NVS ไม่ได้รับประกันว่าเขียนทับข้อมูลเก่าใน flash ทุกไบต์ (เป็นพฤติกรรมของ NVS ทั่วไป ผู้ที่ถอด flash ไปวิเคราะห์ระดับต่ำอาจกู้บางส่วนได้) ถ้าต้องการลบแน่นอนให้แฟลชลบทั้งชิป (`erase_flash`) ก่อนทิ้งบอร์ด

## ชั้นที่ 8: การจัดการความลับ (secrets management)

**ภัยคุกคาม:** รหัสผ่านฝังในโค้ดแล้วขึ้น git, ใช้ค่าตัวอย่างจริงบนเซิร์ฟเวอร์, secret หลุดผ่าน `docker inspect`, รหัสแอดมินค้างอยู่ในไฟล์

| มาตรการ | รายละเอียด | ไฟล์ |
|---|---|---|
| สุ่มความลับอัตโนมัติ | `secret()` ใช้ `openssl rand -base64 64` กรองเหลือ `A-Za-z0-9` แล้วตัดเป็น 32–48 ตัว: `DB_ROOT_PASSWORD`, `DB_PASSWORD` (40), `JWT_SECRET`, `OTP_PEPPER`, `MQTT_DEVICE_SECRET` (48), `MQTT_PASSWORD` (32) แต่ละตัวสุ่มแยกกัน (ไม่ซ้ำกัน) | `deploy/init-env.sh` บรรทัด 24, 68–74 |
| สิทธิ์ไฟล์ | `.env` เป็น `chmod 600` (อ่านได้เฉพาะเจ้าของ) สำรอง `.env.bak-*` ก็ `600` และ `dynamic-security.json` เป็น `600` | `init-env.sh` บรรทัด 13, 114, 141 |
| Backend รับเฉพาะ env ที่ใช้ | ใน compose ระบุตัวแปรทีละตัวใน `environment:` ไม่ใช้ `env_file: .env` ทั้งไฟล์ เพราะ `.env` มีรหัส root ของ MariaDB, token DuckDNS/Tailscale และรหัสแอดมินแรก ซึ่งถ้าส่งเข้า container จะเห็นได้ด้วย `docker inspect` | `docker-compose.yml` บรรทัด 72–76 (คอมเมนต์) |
| รหัสแอดมินไม่ค้าง | `seed-admin.sh` ส่งรหัสผ่านเข้า Backend ทาง **stdin** ครั้งเดียว (`--password-stdin`) แล้ว `sed` ล้าง `SEED_ADMIN_PASSWORD=` ออกจาก `.env` | `deploy/seed-admin.sh` บรรทัด 56–58, `backend/scripts/seed-admin.js` |
| ไม่ขึ้น git | `.gitignore`: `.env`, `deploy/.env*`, `deploy/server.config.json`, `mqtt/config/passwords`, `*.jks`, `*.keystore`, `android/key.properties` | `.gitignore`, `backend/.gitignore` |
| บล็อก secret อ่อน | `unsafeSecret` + `assertServerConfig` ไม่ยอมเริ่มถ้า secret สั้นหรือยังเป็นค่าตัวอย่าง | `backend/src/config.js` |
| คีย์เซ็น APK | `android/app/build.gradle.kts` อ่านจาก `android/key.properties` (สร้างด้วย `create-keystore.ps1`) ถ้าไม่มีจะเตือนและเซ็นด้วย debug key | `android/app/build.gradle.kts` บรรทัด 10–22 |

**ไฟล์ `deploy/docker-compose.yml` บรรทัด 72–77 (คอมเมนต์ที่อธิบายเหตุผล)**

```yaml:72
    # ส่งเข้า Backend เฉพาะค่าที่ Backend ใช้จริง ไม่ใช้ `env_file: .env` ทั้งไฟล์
    # เพราะ .env มีรหัส root ของ MariaDB, token DuckDNS/Tailscale และรหัสแอดมินตัวแรก
    # ถ้าส่งไปทั้งไฟล์ ค่าพวกนั้นจะอยู่ใน container และเห็นได้จาก `docker inspect`
    # (ค่าใน ${...} ยังอ่านจาก .env ไฟล์เดิม ไม่ต้องแก้ .env บนเซิร์ฟเวอร์)
    # เพิ่มตัวแปรใหม่ให้ Backend เมื่อไร ต้องมาเพิ่มในรายการนี้ด้วย
    environment:
```

นี่คือ least privilege ระดับ secret: ถ้า Backend ถูกเจาะ คนร้ายไม่ได้รหัส root ของฐานข้อมูล, token DuckDNS หรือ Tailscale ไปด้วย (ได้เฉพาะที่ Backend ใช้จริง)

**ไฟล์ `deploy/seed-admin.sh` บรรทัด 56–58**

```bash:56
if grep -qE '^SEED_ADMIN_PASSWORD=.+' .env; then
  sed -i 's/^SEED_ADMIN_PASSWORD=.*/SEED_ADMIN_PASSWORD=/' .env
```

`init-env.sh` ถามรหัสแอดมินแรกแล้วเขียนลง `.env` ชั่วคราว (บรรทัด 103) จากนั้น `seed-admin.sh` ใช้แล้วล้างทิ้ง รหัสแอดมินจึงไม่อยู่เป็นข้อความธรรมดาบนดิสก์ถาวร (ในฐานข้อมูลเป็น bcrypt hash)

**จุดอ่อนที่เหลือ:** `.env` ยังเก็บความลับทั้งหมดเป็นข้อความธรรมดาบนดิสก์ (อ่านได้ด้วย root และเจ้าของ `SUDO_USER`) ถ้าเซิร์ฟเวอร์ถูกยึดก็ได้ครบ ทางที่ดีกว่าคือใช้ Docker secrets/ตัวจัดการความลับ และ `JWT_SECRET` ไม่มีกลไกหมุนเวียน (rotation) ที่ไม่ทำให้ทุกคนหลุด (`token_version` ใช้เพิกถอนรายบัญชีเท่านั้น) และ `backend/.env.example` มีค่าตัวอย่างที่ปลอดภัยสำหรับพัฒนาแต่ใช้ `DB_USER=root`, `APP_ORIGIN=*` ต้องไม่ใช้บนเซิร์ฟเวอร์จริง

## ชั้นที่ 9: คอนเทนเนอร์

**ไฟล์ `deploy/backend.Dockerfile` บรรทัด 19–21**

```text:19
# รันด้วย user ธรรมดาที่ image เตรียมไว้ ไม่ใช่ root
# ถ้าวันหนึ่ง Backend มีช่องโหว่ คนร้ายจะได้สิทธิ์แค่ user นี้ใน container
USER node
```

- **Backend รันเป็น user `node`** (ไม่ใช่ root) `npm ci --omit=dev` ติดตั้งเฉพาะแพ็กเกจที่ใช้จริงบน production ลดพื้นผิวโจมตี
- **ไฟล์ซอร์สอ่านได้อย่างเดียวสำหรับ user `node`:** `RUN chmod -R a+rX src scripts database` (`backend.Dockerfile` บรรทัด 17 ก่อน `USER node`) แก้ปัญหาไฟล์ที่ `scp` จาก Windows ได้สิทธิ์ 700 จน user `node` เปิด `/app/src` ไม่ได้ (`Cannot find module`) `a+rX` ให้ทุกคน**อ่าน**และเข้าโฟลเดอร์ได้ แต่ไม่ให้**เขียน** และไฟล์ยังเป็นของ root จึงเป็น least privilege (โปรเซสที่ถูกยึดแก้ซอร์สใน container ไม่ได้) ไม่แตะ `node_modules` เพราะมีหลายพันไฟล์และสิทธิ์ถูกอยู่แล้ว
- **mount แบบอ่านอย่างเดียว (`:ro`)**: Mosquitto config และ certs (`docker-compose.yml` บรรทัด 51–52), `Caddyfile`, `www`, `firmware` ใน Caddy (บรรทัด 163–166), และ `tailscale-serve.json` (บรรทัด 195) แปลว่าต่อให้ process ในนั้นถูกยึด ก็แก้ไฟล์ต้นฉบับ (เว็บ, config) ไม่ได้ ที่เขียนได้มี `db/data`, `mosquitto/data`, `caddy/data`, `tailscale/state` ที่จำเป็นต้องเขียน และ **โฟลเดอร์ firmware ใน Backend** (บรรทัด 126) ซึ่งเดิมเป็น `:ro` แต่ตั้งแต่ 14 ต.ค. 2569 ต้องเขียนได้เพื่อรับไฟล์ที่อัปโหลดจากเว็บ (เป็นการแลกความสะดวกกับสิทธิ์ที่เพิ่มขึ้น ดูหัวข้อ 7.5) ส่วนโฟลเดอร์ firmware ฝั่ง Caddy ยังอ่านอย่างเดียว
- **จำกัดขนาด log** ทุก container (`x-logging` บรรทัด 3–9: `max-size: "10m"`, `max-file: "5"` = ไม่เกิน 50 MB ต่อ container) ป้องกันดิสก์เต็มจน **ระบบล่ม (Availability)** เพราะค่าเริ่มต้นของ Docker ไม่จำกัด Caddy ก็หมุน access log ของตัวเอง (`roll_size 10MiB`, `roll_keep 5`)
- `restart: unless-stopped` และ `healthcheck` ของ db/mqtt/backend ให้ระบบฟื้นเองเมื่อล้ม และ `depends_on: condition: service_healthy` ให้ Backend รอฐานข้อมูลพร้อมก่อน
- **ผู้ใช้ฐานข้อมูลแยกสิทธิ์:** Backend ใช้ `DB_USER` (`rmutt_app`) ที่มีสิทธิ์เฉพาะฐานข้อมูล `${DB_DATABASE}` (MariaDB สร้างให้อัตโนมัติจาก `MARIADB_USER`) ส่วน root ใช้เฉพาะงานดูแลระบบ (backup, db-view)

**จุดอ่อนที่เหลือ:** ตรวจ `docker-compose.yml` แล้ว **ไม่มี** `read_only: true` (ระบบไฟล์ของ container ยังเขียนได้), `cap_drop: [ALL]`, หรือ `security_opt: [no-new-privileges:true]` และ container อื่น (db, mqtt, caddy) ไม่ได้ตั้ง `user:` เอง (พึ่ง image ที่ลดสิทธิ์ภายในเอง) สามารถเพิ่ม hardening เหล่านี้ให้ Backend ได้โดยแทบไม่เสียค่าใช้จ่าย

## ชั้นที่ 10: การสำรองข้อมูล (backup)

**ภัยคุกคาม:** ดิสก์เสีย ลบข้อมูลผิด หรือถูก ransomware สูญเสียประวัติค่าไฟทั้งหมด (Availability และ Integrity)

**ไฟล์ `deploy/backup-db.sh`** cron รันทุกวัน **02:30** (ตั้งโดย `setup-vps.sh` บรรทัด 104) ทำสิ่งต่อไปนี้

- `mariadb-dump --single-transaction --routines --triggers --events` ผ่าน `docker compose exec` แล้ว `gzip -9` — `--single-transaction` อ่านข้อมูลชุดเดียวกันทั้งไฟล์โดยไม่ล็อกตาราง ระบบบันทึกค่าไฟต่อได้ระหว่างสำรอง
- เขียนลงไฟล์ `.partial` ก่อน แล้ว **ตรวจว่าสมบูรณ์** (`gzip -t` และบรรทัดสุดท้ายมี `Dump completed`) จึง `mv` เป็นชื่อจริง ไฟล์ที่ dump ไม่ครบจะไม่ถูกนับเป็น backup (กันเข้าใจผิดว่ามี backup ทั้งที่ใช้กู้ไม่ได้)
- สิทธิ์: โฟลเดอร์ `backups` เป็น `700` ไฟล์ `600` (`chmod 700 backups`, `chmod 600 "$FILE"`)
- เก็บย้อนหลัง `BACKUP_KEEP_DAYS` (ค่าเริ่มต้น 14 วัน, `find ... -mtime +N -delete`)
- ถ้าตั้ง `BACKUP_REMOTE` จะ `rsync` ไปเครื่องอื่นผ่าน SSH key เพื่อไม่ให้ backup อยู่ที่เดียวกับข้อมูลจริง

**จุดอ่อนที่เหลือ:** ไฟล์ backup **ไม่ได้เข้ารหัส** (มี hash รหัสผ่านและข้อมูลทั้งหมด) และ `BACKUP_REMOTE` ว่างโดยค่าเริ่มต้น ซึ่งแปลว่า backup อยู่ดิสก์เดียวกับข้อมูล (ดิสก์พังก็หายทั้งคู่) ไม่ได้สำรอง `.env`, `mosquitto/data/dynamic-security.json` และใบรับรอง (ส่วนบัญชีบอร์ดสร้างคืนได้จาก `reconcileAccounts` แต่ `.env` หายคือ secret หายหมด) และไม่มีการทดสอบกู้คืนอัตโนมัติ

## ตารางสรุปตามชั้น

| ชั้น | ภัยคุกคาม | วิธีป้องกันในโปรเจค | ไฟล์ |
|---|---|---|---|
| เครือข่าย | สแกนพอร์ตเจอ DB/SSH/Broker | DB ผูก `127.0.0.1`, Backend/1883 ไม่ publish, Funnel ส่งเข้า `caddy:8080` (443) กับ `mqtt:1883` (8443) เท่านั้น, ufw default deny, SSH tunnel | `docker-compose.yml`, `tailscale-serve.json`, `setup-vps.sh`, `db-tunnel.ps1` |
| TLS | ดักอ่าน/แก้ข้อมูล (MITM) | Let's Encrypt (DNS-01 DuckDNS), HSTS, MQTTS (Funnel 8443 ใบ ts.net / ต่อตรง 8883 TLS1.2+), root CA ในเฟิร์มแวร์ (X1+X2), OTA ผ่าน HTTPS | `Caddyfile`, `mosquitto.conf`, `letsencrypt_ca.h`, `ota_update.h` |
| เว็บ | XSS, clickjacking, API ปลอม | CSP `script-src 'self'`, `frame-ancestors 'none'`, nosniff, `textContent` ใน `dom.js`, `?api=` เฉพาะ localhost | `Caddyfile`, `dom.js`, `config.js` |
| API: ตัวตน | ปลอม/ใช้ token ซ้ำ | JWT HS256 (pin อัลกอริทึม, iss/aud, 8 ชม.), `token_version`, อ่าน role จาก DB ทุกคำขอ | `authenticate.js`, `auth.js` |
| API: สิทธิ์ | staff ทำงานของ admin | `requireAdmin` (403), กัน admin คนสุดท้าย | `require-admin.js`, `users.js` |
| API: การจำกัด | เดารหัส, ล็อกอินรัว | login 10/15 นาที, ยืนยันรหัสผิด 10/15 นาที, reset 8/ชม., `TRUST_PROXY=2` | `auth.js`, `docker-compose.yml`, `config.js` |
| API: ข้อมูล | SQL injection, ข้อมูลรั่ว | parameterized `?`, regex/allowlist, `limit: 256kb`, error กลาง ๆ, `/api/health` ย่อบน production | `app.js`, `http.js`, `air-conditioner.js` |
| รหัสผ่าน/OTP | ฐานข้อมูลรั่ว, เดา OTP, timing | bcryptjs cost 12, dummy hash, OTP HMAC+pepper, หมดอายุ 10 นาที, 5 ครั้ง/OTP, reset token hash ใช้ครั้งเดียว | `security.js`, `auth.js` |
| MQTT | สั่งแอร์ผิดห้อง, ฟังข้ามห้อง | `allow_anonymous false`, Dynamic Security บัญชี+ACL ต่อบอร์ด, รหัส = HMAC(Device ID), role ของ Backend | `mosquitto.conf`, `mqtt-accounts.js` (utils/services) |
| อุปกรณ์/BLE | บอร์ดปลอม, ชี้บอร์ดไป Broker อื่น, ความลับค้างในบอร์ดที่เลิกใช้ | provisioning token สุ่ม hash หมดอายุ 15 นาที ใช้ครั้งเดียว, กู้ Wi-Fi แก้ได้แค่ Wi-Fi, setup admin-only 5 นาที, OTA จำกัด URL + ตรวจ CA + ไฟล์ตรงชนิดบอร์ด, unprovision ล้าง NVS ตอนลบอุปกรณ์ | `air-conditioners.js`, `occupancy-sensors.js`, `mqtt.js`, `unprovision.js`, `rmutt_esp32_air.ino`, `ota_update.h` |
| อัปโหลดเฟิร์มแวร์ | path traversal, ไฟล์ผิดชนิด/ไม่ใช่เฟิร์มแวร์, ไฟล์ใหญ่ | admin-only, regex ชื่อไฟล์ + ห้าม `..`, `?kind` ต้องตรง, magic byte `0xE9`, ≤ `0x1F0000`, `?replace=1`, เขียน `.part` + rename, log ผู้อัปโหลด | `routes/firmware.js`, `utils/firmware.js` |
| ความลับ | secret หลุด/ฝังโค้ด | `init-env.sh` สุ่ม, `.env` 600, env เฉพาะที่ใช้, seed-admin ล้างรหัส, `.gitignore`, keystore แยก | `init-env.sh`, `docker-compose.yml`, `seed-admin.sh`, `.gitignore` |
| คอนเทนเนอร์ | ถูกยึด container, ดิสก์เต็ม | `USER node` + `chmod -R a+rX` (อ่านอย่างเดียว), mount `:ro` (ยกเว้น firmware ของ Backend ตั้งแต่ 14 ต.ค. 2569), จำกัด log 10MB×5, healthcheck | `backend.Dockerfile`, `docker-compose.yml` |
| สำรองข้อมูล | ข้อมูลหาย | cron 02:30, ตรวจไฟล์ครบ, 600/700, เก็บ 14 วัน, rsync ออกนอก | `backup-db.sh`, `setup-vps.sh` |

## จุดอ่อนที่ยังเหลือและข้อเสนอปรับปรุง

รายการนี้ตรวจกับโค้ดจริงแล้ว ใช้ตอบอาจารย์ได้อย่างตรงไปตรงมา การยอมรับข้อจำกัดอย่างมีเหตุผลดีกว่าอ้างว่า "ปลอดภัย 100%"

| # | จุดอ่อน | หลักฐานในโค้ด | ผลกระทบ | ข้อเสนอ |
|---|---|---|---|---|
| 1 | OTA ไม่มี code signing / secure boot / rollback | ไม่พบใน `firmware/`; ไฟล์ `.bin` เสิร์ฟสาธารณะที่ `/firmware/*` (`Caddyfile` 35–39); ตั้งแต่ 14 ต.ค. 2569 แอดมินอัปโหลดไฟล์ผ่านเว็บได้ (`POST /api/firmware` ตรวจแค่รูปแบบ `0xE9`/ขนาด ไม่ตรวจความแท้) | ผู้ที่วางไฟล์บนเซิร์ฟเวอร์ได้ (SSH หรือบัญชีแอดมินเว็บ) ควบคุมบอร์ดทุกตัวได้; ไฟล์เสียแต่ครบ = บอร์ดบูตไม่ขึ้น | เซ็นเฟิร์มแวร์, เปิด app rollback, flash encryption |
| 2 | **staff สั่งแอร์ได้ทุกเครื่อง** | `POST /:deviceId/command` (`air-conditioners.js` บรรทัด 238–239) ไม่มี `requireAdmin` มีแค่ `authenticate` ที่ระดับ router (บรรทัด 39) และ role ในระบบมีแค่ `admin`/`staff` (`schema.sql` บรรทัด 8) | บัญชี staff ที่ถูกขโมยสั่งปิด/เปิดแอร์ทั้งอาคารได้ (อาจตั้งใจเพราะผู้ใช้หลักคือเจ้าหน้าที่ แต่ควรเป็นการตัดสินใจที่จดไว้) | แยกสิทธิ์รายห้อง/ชั้น หรือ role `operator`; จำกัดอัตราคำสั่งต่อผู้ใช้ |
| 3 | `PUBLIC_URL` ไม่ถูกตั้งโดย `init-env.sh` และไม่อยู่ใน `.env` ตัวอย่าง/`DEPLOY.md` | `grep PUBLIC_URL` พบเฉพาะ `docker-compose.yml` บรรทัด 88 (`${PUBLIC_URL:-}`) ค่าที่ได้คือ `https://<โดเมน>,` | **เว็บ** ที่เปิดผ่าน `https://...ts.net` จะส่ง `Origin` ที่ไม่อยู่ในรายการ CORS ในคำขอ POST (เช่น login) → Backend ตอบ 500 (ข้อสรุปจากการอ่านโค้ด `createCorsOptions` + `errorHandler` ควรทดสอบจริงก่อนอ้าง) ส่วนแอปมือถือไม่ถูกกระทบเพราะไม่ส่ง `Origin` | ให้ `init-env.sh` ถามและเขียน `PUBLIC_URL`, อธิบายใน `DEPLOY.md` |
| 4 | ไม่มี handler 401 ระดับแอป (Flutter) | แต่ละ service โยน `ApiException('Please sign in again.', statusCode: 401)` (เช่น `energy_service.dart` บรรทัด 147) แต่ controller แปลงเป็นข้อความผิดพลาดธรรมดา ไม่พบการเด้งออกอัตโนมัติ (เว็บมี `api.js` บรรทัด 128 ที่จัดการ 401 ที่เดียว) | token หมดอายุ/ถูกเพิกถอนแล้วผู้ใช้เห็นข้อความ error ทุกหน้าจนกว่าจะออกจากระบบเอง | ทำ HTTP interceptor กลางที่ล้าง token แล้วกลับหน้า login |
| 5 | `AlertNotifier` ไม่ได้ต่อสาย | `main.dart` บรรทัด 34 `runApp(const CpeAirRemoteApp())` ไม่ส่ง `alertNotifier` เข้าไป (บรรทัด 49, 175 รับเป็น nullable) ตัวที่มีคือ `NoopAlertNotifier` | การแจ้งเตือนผิดปกติ (เช่น แอร์เปิดเกินเวลา) ไม่ถึงผู้ดูแลแบบ push จึงเป็นเรื่อง Availability/การตอบสนองต่อเหตุ | ต่อ notifier จริง (local notification/FCM) |
| 6 | `db-view.sh` ใช้ root และรัน SQL อะไรก็ได้ | `db-view.sh` บรรทัด 322, 327–330: อ่าน `DB_ROOT_PASSWORD` และคำสั่ง `sql` รันข้อความใดก็ได้ ทั้งที่หัวไฟล์ระบุว่า "อ่านอย่างเดียว" | ไม่ใช่ read-only จริง ใช้สิทธิ์เกินจำเป็น | ใช้ user ฐานข้อมูลแบบ `SELECT` อย่างเดียว |
| 7 | บัญชีเริ่มต้น MQTT ถอยเป็น `shared` เงียบ ๆ | `normalizeDeviceAuthMode` (`utils/mqtt-accounts.js` บรรทัด 35–38) คืน `shared` ถ้าไม่ได้ตั้งค่า; `config.js` มีแค่ warn บรรทัด 116–120 | ลืมตั้ง env = ทุกบอร์ดใช้รหัสเดียว | บังคับ `dynsec` เมื่อ `NODE_ENV=production` |
| 8 | BLE ไม่มี pairing/encryption | ดูหัวข้อ 7 | ดักรหัสตอนตั้งค่า, แย่งตั้งค่าใน 5 นาที | ใช้ LE Secure Connections + passkey หรือเข้ารหัสข้อมูลระดับแอปด้วยคีย์ที่แลกกับ Backend |
| 9 | rate limit เฉพาะ `auth.js`, ตัวนับอยู่ในหน่วยความจำ | ค้น `rateLimit(` พบเฉพาะ `auth.js`; ไม่ได้กำหนด `store` | API อื่นถูกยิงถี่ได้ (มี JWT เท่านั้น); MQTT ผ่าน Funnel 8443 ก็ไม่มี rate limit ต่อ IP (ดูข้อ 15); รีสตาร์ท Backend ล้างตัวนับ; ไม่มี lockout ต่อบัญชี (นับต่อ IP) | rate limit ทั้ง `/api`, เก็บตัวนับใน Redis/DB |
| 10 | `GET /api/public/admin-contact` เปิดไม่ต้องล็อกอิน | `routes/public.js` ตอบชื่อและเบอร์ของแอดมิน | เป็นข้อมูลที่ตั้งใจเปิดให้หน้า login (ติดต่อแอดมิน) แต่คนนอกเก็บเบอร์ไปได้ และถ้าไม่มีชื่อจะแสดง username ของ admin (บรรทัด 34) | ยอมรับได้ถ้าตั้งใจ ควรไม่คืน username |
| 11 | JWT เพิกถอนรายตัวไม่ได้ / ไม่มี logout ฝั่งเซิร์ฟเวอร์ / อายุ 8 ชม. ไม่มี refresh | ไม่มี endpoint logout ใน `auth.js`; เพิกถอนได้เฉพาะด้วยการบวก `token_version` ทั้งบัญชี | token ที่หลุดใช้ได้จนกว่าจะเปลี่ยนรหัส/โดนปิดบัญชี | access token สั้น + refresh token ที่เพิกถอนได้ |
| 12 | timing/enumeration ที่ `forgot-password` | `auth.js` บรรทัด 261–298 รอส่งอีเมลเฉพาะกรณีมีบัญชี | เดาได้ว่าบัญชีมีหรือไม่จากเวลาตอบ | ส่งอีเมลเบื้องหลัง |
| 13 | ใช้ `OTP_PEPPER` ตัวเดียวกับ token ผูกบอร์ดด้วย | `air-conditioners.js` บรรทัด 147, `mqtt.js` ใช้ `config.otpPepper` | ใช้กุญแจเดียวหลายหน้าที่ ถ้ารั่วกระทบทั้งคู่ | แยกกุญแจต่อหน้าที่ |
| 14 | ฮาร์เดนนิงของ SSH/ฐานข้อมูลสำรอง/เครื่องมือ | `db-tunnel.ps1` ถามรหัสผ่าน SSH; backup ไม่เข้ารหัส และ `BACKUP_REMOTE` ว่าง; ไม่มี `cap_drop`/`read_only` | ดูหัวข้อชั้น 1, 9, 10 | ใช้ SSH key อย่างเดียว, เข้ารหัส backup (เช่น `age`/`gpg`) |
| 15 | Broker เข้าถึงได้จากอินเทอร์เน็ตผ่าน Funnel 8443 และไม่มี rate limit/ตัวแบน IP ที่ชั้น MQTT | `tailscale-serve.json` บรรทัด 4–7 และ 18 เปิดพอร์ต 8443 → `mqtt:1883`; `mosquitto.conf` ไม่มีการตั้งค่าจำกัดการเชื่อมต่อหรือการล็อกอินผิด และ Mosquitto เห็นต้นทางเป็นกล่อง tailscale | ยิงการเชื่อมต่อใส่ Broker เพื่อกินทรัพยากรหรือทำ log รกได้ (รหัสบอร์ดเป็น HMAC เดาในทางปฏิบัติไม่ได้ แต่ถ้า `MQTT_DEVICE_SECRET` หรือบัญชีหลุดก็ต่อจากนอกอาคารได้ทันที) ช่วงสุดท้ายถึง Mosquitto เป็น MQTT ดิบในเครือข่าย docker | ใช้ 8883 ต่อตรงและถอด 8443 เมื่อบอร์ดอยู่ในอาคารหมด, เฝ้าดู log (`connection_messages true`), เพิ่มตัวนับ/แบน IP หน้า Broker |
| 16 | Backend เขียนโฟลเดอร์ firmware ได้ (เพิ่ม 14 ต.ค. 2569) | `docker-compose.yml` บรรทัด 126 ไม่มี `:ro` แล้ว; `setup-vps.sh`/`update-remote.sh` ตั้งเจ้าของเป็น uid 1000 | Backend ที่ถูกยึดเปลี่ยนไฟล์ `.bin` ที่บอร์ดจะดาวน์โหลดได้ | เซ็นเฟิร์มแวร์ (ข้อ 1) หรือแยกบริการรับไฟล์ที่มีสิทธิ์เขียนเฉพาะโฟลเดอร์นี้ |
| 17 | บอร์ดออฟไลน์ตอนลบ ยังเก็บรหัส Wi-Fi ใน NVS (เพิ่ม 13 ต.ค. 2569) | `unprovisionDevice` ไม่ส่งแบบ retain และรอแค่ 4 วินาที; คำตอบ `boardCleared: false` | รหัส Wi-Fi ของอาคารค้างในบอร์ดที่ถูกถอดไป | แจ้งเตือนในแอปเมื่อ `boardCleared` เป็น false, ขั้นตอนเก็บคืนบอร์ด + `erase_flash`, flash encryption |

> [!WARN]
> ข้อ 2 และ 3 ควรทดสอบกับระบบจริงก่อนไปบอกอาจารย์ว่าเป็นข้อเท็จจริง (ข้อ 2 ยืนยันได้จากโค้ดตรง ๆ ว่าเส้นทางไม่ตรวจ role ส่วนข้อ 3 เป็นผลจากการวิเคราะห์ลำดับ CORS ของ Express ไม่ได้รันจริง)

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **1. ระบบนี้ป้องกันการเดารหัสผ่านอย่างไร**
> สามชั้น (1) rate limit การล็อกอิน 10 ครั้งต่อ 15 นาทีต่อ IP (`loginLimiter` ใน `auth.js`) (2) เก็บรหัสผ่านด้วย bcrypt cost 12 ซึ่งช้าโดยตั้งใจ ถ้าฐานข้อมูลรั่วก็เดาออฟไลน์ได้ช้ามาก (3) ข้อความ error กลาง ๆ และใช้ dummy hash ให้เวลาตอบใกล้เคียงกัน คนร้ายจึงเดา username ไม่ได้ ตั้ง `TRUST_PROXY=2` ให้ IP ที่นับเป็นของผู้ใช้จริง ไม่ใช่ของ proxy

> [!ASK]
> **2. ทำไมใช้ JWT แล้วยังต้อง query ฐานข้อมูลทุกคำขอ ไม่ขัดกับแนวคิด stateless หรือ**
> ขัดบางส่วนโดยตั้งใจ JWT ล้วน ๆ เพิกถอนไม่ได้จนหมดอายุ ระบบนี้ต้องการให้ปิดบัญชี เปลี่ยนรหัสผ่าน หรือลดสิทธิ์แล้วมีผลทันที จึงตรวจ `is_active`, `role` และ `token_version` จากฐานข้อมูลใน `authenticate.js` ทุกครั้ง แลกกับ query เล็ก ๆ หนึ่งครั้งต่อคำขอ ซึ่งรับได้เพราะผู้ใช้หลักหลายสิบคน และ role จึงมาจากฐานข้อมูลไม่ใช่จาก token

> [!ASK]
> **3. ฐานข้อมูลเปิดสู่อินเทอร์เน็ตหรือไม่ ถ้าอยากดูข้อมูลทำอย่างไร**
> ไม่เปิด พอร์ต 3306 ผูกที่ `127.0.0.1` ของเซิร์ฟเวอร์เท่านั้น (`docker-compose.yml` บรรทัด 29) ถ้าต้องการดูข้อมูลจากเครื่องตัวเองใช้ SSH tunnel (`db-tunnel.ps1`) ซึ่งเข้ารหัสทั้งเส้นทางและใช้บัญชีฐานข้อมูลของแอป (ไม่ใช่ root) ข้อควรระวังคือ Docker ข้าม ufw ได้ จึงต้องพึ่งการผูก localhost ในไฟล์ compose ไม่ใช่แค่ firewall

> [!ASK]
> **4. ถ้าบอร์ด ESP32 ตัวหนึ่งถูกขโมยไปอ่านรหัสใน flash จะเกิดอะไรขึ้น**
> ได้แค่รหัสผ่านและ Wi-Fi ของบอร์ดนั้น เพราะแต่ละบอร์ดมีบัญชี MQTT ของตัวเอง (username = Device ID, รหัส = HMAC ของ Device ID ด้วย `MQTT_DEVICE_SECRET`) และ ACL อนุญาตให้ publish/subscribe เฉพาะ topic ของตัวเอง ไม่มีสิทธิ์ publish ที่ topic `command` ใด ๆ จึงสั่งแอร์ห้องอื่นไม่ได้ ผู้ดูแลถอดบอร์ดออกจากระบบเพื่อลบบัญชีนั้นได้ (`removeDeviceAccount`) ข้อจำกัด: flash ของ ESP32 ไม่ได้เข้ารหัส (ไม่ได้เปิด flash encryption) ดังนั้นคนที่ถือบอร์ดอ่านรหัส Wi-Fi ของอาคารออกมาได้

> [!ASK]
> **5. XSS คืออะไร ระบบกันอย่างไร และทำไมต้องกังวลเรื่อง token ใน localStorage**
> XSS คือการแทรกสคริปต์เข้าหน้าเว็บ กัน 2 ชั้น: โค้ด DOM ใช้ `textContent`/`createTextNode` เสมอ (`dom.js`) ไม่เอาข้อมูลผู้ใช้ไปต่อ HTML และ CSP `script-src 'self'` + `connect-src 'self'` ทำให้สคริปต์แปลกปลอมรันไม่ได้และส่งข้อมูลออกนอกโดเมนไม่ได้ ที่ต้องกังวลเพราะ `localStorage` ถูก JavaScript อ่านได้ ถ้าหลุดสองชั้นก็ขโมย token ได้ จึงลดความเสียหายด้วยอายุ token 8 ชั่วโมงและการเพิกถอนด้วย `token_version` เหตุผลที่ไม่ใช้ cookie คือจะเกิดความเสี่ยง CSRF เพิ่ม

> [!ASK]
> **6. ทำไม OTP ถึงใช้ HMAC ไม่ใช่ bcrypt เหมือนรหัสผ่าน**
> OTP มีเพียง 1,000,000 แบบ ถ้า hash ธรรมดา คนที่ได้ตารางไปคำนวณครบทุกแบบได้ทันที HMAC ต้องใช้ pepper ที่เก็บแยกใน `.env` ไม่อยู่ในฐานข้อมูล ขโมยฐานข้อมูลอย่างเดียวจึงถอดไม่ได้ และ OTP อายุแค่ 10 นาที เดาได้ 5 ครั้งต่ออัน การใช้ bcrypt ที่ช้าจึงไม่คุ้ม ส่วนรหัสผ่านอยู่ถาวรและเดาออฟไลน์ได้นาน ต้องใช้ bcrypt

> [!ASK]
> **7. TLS ของ Caddy ได้ใบรับรองมาอย่างไรทั้งที่เซิร์ฟเวอร์อยู่หลังเครือข่ายมหาวิทยาลัย**
> ใช้ DNS-01 challenge ผ่านปลั๊กอิน DuckDNS ใน Caddy: Caddy เขียน TXT record `_acme-challenge` ผ่าน API ด้วย `DUCKDNS_TOKEN` แล้ว Let's Encrypt ตรวจจาก DNS ไม่ต้องเข้ามาที่พอร์ต 80 ของเซิร์ฟเวอร์ ใบนี้ถูกคัดลอกให้ Mosquitto ใช้กับ MQTTS ด้วย (`sync-mqtt-cert.sh`) ส่วนบอร์ดตรวจใบด้วย root CA ของ Let's Encrypt ที่ฝังในเฟิร์มแวร์ ทั้ง X1 (RSA) และ X2 (ECDSA)

> [!ASK]
> **8. มี rate limit ตรงไหนบ้าง และตัวเลขเท่าไร**
> ทั้งหมดใน `auth.js`: login 10 ครั้ง/15 นาที, เปลี่ยนรหัสผ่านหรืออีเมลยืนยันรหัสผิด 10 ครั้ง/15 นาที (นับเฉพาะครั้งที่ผิด), ลืมรหัสผ่าน/ตรวจ OTP/ตั้งรหัสใหม่ รวมกัน 8 ครั้ง/ชั่วโมง นอกจากนี้ OTP แต่ละอันผิดได้ 5 ครั้ง จุดที่ควรปรับปรุงคือยังไม่มี rate limit ที่ API อื่น และตัวนับอยู่ในหน่วยความจำ ส่วนทาง MQTT (Funnel 8443) ไม่มี rate limit ต่อ IP ป้องกันด้วยบัญชีรายบอร์ดเท่านั้น

> [!ASK]
> **9. OTA อัปเดตเฟิร์มแวร์ปลอดภัยแค่ไหน มีจุดอ่อนอะไร**
> ป้องกันสามชั้น: คำสั่งส่งได้เฉพาะ Backend (ACL) และเฉพาะ admin เรียก (และตั้งแต่ 14 ต.ค. 2569 Backend ไม่ยอมสั่งไฟล์ที่ชนิดไม่ตรงกับบอร์ด), บอร์ดยอมรับเฉพาะ URL `https://<host ของ Broker ตัวเอง>/firmware/<ชื่อไฟล์ .bin>` ที่ผ่านการตรวจอักขระ, และตรวจใบรับรอง HTTPS กับ root CA จุดอ่อนที่ต้องยอมรับคือไม่มีการเซ็นเฟิร์มแวร์ ไม่มี secure boot และไม่มี rollback ดังนั้นความถูกต้องของไฟล์ขึ้นกับว่าเซิร์ฟเวอร์ไม่ถูกเจาะ ถ้าจะปรับปรุงให้เซ็นไฟล์ด้วยคีย์ที่เก็บนอกเซิร์ฟเวอร์และเปิด rollback

> [!ASK]
> **10. ถ้ามีคนส่งลิงก์ `?api=https://เว็บร้าย` มาให้ผู้ใช้จะเกิดอะไร**
> ไม่เกิดผล `config.js` ของเว็บรับพารามิเตอร์ `?api=` เฉพาะตอนเปิดจาก `localhost`/`127.0.0.1` เท่านั้น บนโดเมนจริงจะลบค่าที่อาจฝังไว้ใน `localStorage` ทิ้งแล้วใช้ `/api` ของโดเมนตัวเองเสมอ ไม่เช่นนั้นผู้ใช้จะส่ง username/password ไปเว็บของคนร้ายทุกครั้งที่ล็อกอิน (ลิงก์ฟิชชิงที่มาจากโดเมนจริง)

> [!ASK]
> **11. ถ้าให้บอกจุดอ่อนที่ยังเหลือของระบบ 3 ข้อ คืออะไร**
> (1) OTA ไม่มีการเซ็นเฟิร์มแวร์/rollback (2) บัญชี staff สั่งแอร์ได้ทุกเครื่อง เพราะเส้นทาง command ไม่ได้จำกัดสิทธิ์รายห้อง (3) BLE ตอนตั้งค่าไม่มี pairing/เข้ารหัส และ rate limit มีเฉพาะส่วน auth ผมเลือกยอมรับบางข้อโดยมีเหตุผล เช่นเปิด `/firmware/*` สาธารณะเพราะบอร์ดไม่มี JWT และเสนอแนวแก้ทุกข้อไว้ในบท

> [!ASK]
> **12. เปิด MQTT ให้ ESP32 ผ่าน Funnel แล้ว Broker ไม่เสี่ยงหรือ**
> เสี่ยงขึ้นกว่าเดิมจริง เพราะเดิม Broker ต่อได้เฉพาะในเครือข่ายมหาวิทยาลัย ตอนนี้ใครก็ต่อ `ts.net:8443` ได้ เราจึงพึ่ง 3 ชั้น: TLS ถอดที่กล่อง tailscale, ไม่ยอม anonymous และบัญชี Dynamic Security รายบอร์ดที่รหัสเป็น HMAC เดาไม่ได้, ACL ให้บอร์ดเห็นเฉพาะ topic ตัวเอง สิ่งที่ยังขาดคือ rate limit ต่อ IP ที่ชั้น MQTT และช่วงจาก tailscale ไป Mosquitto เป็น MQTT ดิบในเครื่องเดียวกัน ถ้าบอร์ดทั้งหมดอยู่ในอาคาร สามารถตั้ง `MQTT_DEVICE_URL=mqtts://<DOMAIN>:8883` แล้วถอดพอร์ต 8443 ออกจาก `serve.json` ได้

> [!ASK]
> **13. ให้แอดมินอัปโหลดเฟิร์มแวร์จากเว็บได้ ตรวจอะไรบ้าง และเพิ่มความเสี่ยงอะไร**
> ตรวจตามลำดับ: ต้องเป็นแอดมิน, Express ไม่อ่าน body เกิน `0x1F0000 + 1024` ไบต์, ชื่อไฟล์ผ่าน allowlist regex ลงท้าย `.bin` ไม่มี `/` หรือ `..` (กัน path traversal), ชนิดจากชื่อต้องตรงแท็บ, ไบต์แรกต้องเป็น `0xE9` และไม่เกินช่องโปรแกรม, ไม่ทับไฟล์เดิมถ้าไม่ยืนยัน แล้วเขียนผ่านไฟล์ `.part` + rename และ log ว่าใครอัปโหลด ความเสี่ยงที่เพิ่มคือรหัสแอดมินเว็บอย่างเดียวก็วางเฟิร์มแวร์ให้ทุกบอร์ดได้ และ Backend ต้องเขียนโฟลเดอร์ firmware ได้ (เลิก `:ro`) การตรวจ `0xE9` เป็นแค่ตรวจรูปแบบ ไม่ใช่ลายเซ็น ทางแก้จริงคือ code signing

> [!ASK]
> **14. ลบอุปกรณ์แล้ว รหัส Wi-Fi ที่อยู่ในบอร์ดยังอยู่ไหม**
> ถ้าบอร์ดออนไลน์ตอนลบ ไม่อยู่ครับ Backend ส่งคำสั่ง `unprovision` (มี `deviceId` ให้บอร์ดตรวจซ้ำ) บอร์ดตอบกลับแล้วล้าง NVS ทั้ง Wi-Fi, MQTT, ห้อง แล้วรีบูตเป็นบอร์ดเปล่า Backend รอคำตอบ 4 วินาทีก่อนลบบัญชี MQTT เพราะถ้าลบบัญชีก่อนคำสั่งจะไปไม่ถึง ถ้าบอร์ดออฟไลน์ แอปได้ `boardCleared: false` ต้องไปล้างที่ตัวบอร์ด แต่บอร์ดนั้นต่อ Broker ไม่ได้แล้วเพราะบัญชีถูกลบ

## สรุปและเช็กลิสต์ความเข้าใจ

ภาพรวมที่ต้องจำ: ระบบใช้ **หลายชั้นป้องกัน (defense in depth)** และ **สิทธิ์น้อยที่สุด (least privilege)** ตั้งแต่เครือข่าย (เปิดพอร์ตน้อย, DB ผูก localhost) ผ่าน TLS ทุกเส้นทาง, เว็บ (CSP, ไม่ใช้ `innerHTML` กับข้อมูลผู้ใช้), API (JWT ตรวจกับฐานข้อมูลทุกครั้ง, rate limit, parameterized SQL), รหัสผ่าน (bcrypt, dummy hash, OTP HMAC+pepper), MQTT (บัญชีและ ACL ต่อบอร์ด), อุปกรณ์ (token ผูกบอร์ดใช้ครั้งเดียว, กู้ Wi-Fi แก้ได้แค่ Wi-Fi), การจัดการความลับ (สุ่ม, ส่งเฉพาะที่จำเป็น), คอนเทนเนอร์ (ไม่ใช้ root, `:ro`, จำกัด log) และ backup พร้อมกับยอมรับจุดอ่อนที่เหลืออย่างตรงไปตรงมา

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบาย CIA, authentication vs authorization, hash vs encryption, salt vs pepper ได้ด้วยภาษาตัวเอง
- [ ] บอกได้ว่าพอร์ตไหนเปิดสู่อินเทอร์เน็ต พอร์ตไหนไม่เปิด และ Funnel ส่งต่อไปที่ไหนบ้าง (443 → `caddy:8080`, 8443 → `mqtt:1883`) พร้อมความเสี่ยงของการเปิด 8443
- [ ] อธิบายได้ว่า DNS-01 ต่างจาก HTTP-01 อย่างไร และทำไมโปรเจคนี้ต้องใช้ DNS-01
- [ ] ระบุได้ว่ามี root CA อะไรในเฟิร์มแวร์ และบอร์ดต้องซิงก์เวลา NTP ก่อนต่อ TLS เพราะอะไร
- [ ] ยกตัวอย่าง security header อย่างน้อย 4 ตัวใน Caddyfile และบอกว่ากันอะไร
- [ ] อธิบาย XSS สองชั้นที่ใช้ และ trade-off ของ token ใน `localStorage` เทียบกับ cookie
- [ ] อธิบายได้ว่าทำไม `?api=` ต้องจำกัดเฉพาะ localhost
- [ ] เล่า claim ใน JWT, สิ่งที่ `jwt.verify` ตรวจ, ทำไมต้อง `algorithms: ['HS256']` และ `token_version` ทำอะไร
- [ ] บอกตัวเลข rate limit ทั้งสามตัว (10/15 นาที, 10/15 นาที นับเฉพาะผิด, 8/ชม.) และอธิบายว่าทำไม `TRUST_PROXY=2`
- [ ] อธิบายว่า dummy hash กัน timing attack อย่างไร
- [ ] บอกได้ว่าทำไม OTP ใช้ HMAC+pepper, หมดอายุกี่นาที, ผิดได้กี่ครั้ง และ reset token ถูกเก็บอย่างไร
- [ ] อธิบายได้ว่า ACL ของบอร์ดหนึ่งตัวอนุญาตอะไร และรหัสผ่าน MQTT ของบอร์ดมาจากไหน
- [ ] เล่าวงจร provisioning token (15 นาที, hash, ใช้ครั้งเดียว) และโหมดกู้ Wi-Fi/โหมดตั้งค่าออนไลน์ 5 นาที
- [ ] อธิบายว่า Backend รับ env อย่างไรและทำไมไม่ใช้ `env_file` ทั้งไฟล์
- [ ] ชี้ได้ว่า container ไหนมีมาตรการอะไร (`USER node`, `:ro`, log limit) และยังขาดอะไร
- [ ] ระบุจุดอ่อนที่เหลืออย่างน้อย 5 ข้อพร้อมข้อเสนอแก้ และแยกได้ว่าข้อไหนยืนยันจากโค้ด ข้อไหนเป็นข้อสรุปที่ต้องทดสอบก่อน
- [ ] ไล่ด่านตรวจของ `POST /api/firmware` ได้ครบ และแยกได้ว่าด่านไหนตรวจรูปแบบ ด่านไหนตรวจสิทธิ์ และทำไมยังไม่ใช่การยืนยันความแท้ (เพิ่ม 14 ต.ค. 2569)
- [ ] อธิบาย unprovision ในมุม data hygiene: ล้างอะไร ลำดับก่อนลบบัญชี MQTT และข้อจำกัดเมื่อบอร์ดออฟไลน์ (เพิ่ม 13 ต.ค. 2569)
