FROM node:22-alpine

ENV NODE_ENV=production
ENV TZ=Asia/Bangkok

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# รันด้วย user ธรรมดาที่ image เตรียมไว้ ไม่ใช่ root
# ถ้าวันหนึ่ง Backend มีช่องโหว่ คนร้ายจะได้สิทธิ์แค่ user นี้ใน container
USER node

EXPOSE 3000
CMD ["node", "src/server.js"]
