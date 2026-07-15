FROM node:20-slim AS builder
WORKDIR /app
COPY backend/package*.json ./
RUN npm install
COPY backend/admin-panel/package*.json ./admin-panel/
RUN cd admin-panel && npm install
COPY backend/admin-panel/ ./admin-panel/
RUN cd admin-panel && npm run build

FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/admin-panel/dist ./admin-panel/dist
COPY backend/ .
EXPOSE 3000
VOLUME /app/data
CMD ["node", "src/index.js"]
