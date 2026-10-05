FROM node:22-alpine

ENV NODE_ENV=production
ENV TZ=Asia/Bangkok

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# ไฟล์ที่ scp ขึ้นมาจาก Windows อาจได้สิทธิ์ 700 (อ่านได้แค่เจ้าของ)
# ถ้าไม่ปรับ user node จะเปิด /app/src ไม่ได้และขึ้น Cannot find module
# ให้อ่านได้อย่างเดียว ไฟล์ยังเป็นของ root ทำให้แก้โค้ดใน container ไม่ได้
RUN chmod -R a+rX /app

# รันด้วย user ธรรมดาที่ image เตรียมไว้ ไม่ใช่ root
# ถ้าวันหนึ่ง Backend มีช่องโหว่ คนร้ายจะได้สิทธิ์แค่ user นี้ใน container
USER node

EXPOSE 3000
CMD ["node", "src/server.js"]
