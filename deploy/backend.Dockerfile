FROM node:22-alpine

ENV NODE_ENV=production
ENV TZ=Asia/Bangkok

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

EXPOSE 3000
CMD ["node", "src/server.js"]
