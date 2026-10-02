# Caddy ที่มีปลั๊กอิน DuckDNS สำหรับขอใบรับรองแบบ DNS challenge
#
# ทำไมต้องมี: เซิร์ฟเวอร์อยู่ในเครือข่ายภายในมหาวิทยาลัย (IP 10.x)
# Let's Encrypt เข้ามาตรวจผ่านพอร์ต 80 ไม่ได้ จึงพิสูจน์ความเป็นเจ้าของโดเมน
# ด้วยการเขียน TXT record ที่ DuckDNS แทน ไม่ต้องเปิดพอร์ตใด ๆ ออกอินเทอร์เน็ต
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/duckdns

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
