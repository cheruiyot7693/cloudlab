# ── Development ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS development

WORKDIR /app

COPY package*.json ./
RUN npm ci

# Source mounted as volume in dev
EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host"]

# ── Build ─────────────────────────────────────────────────────────────────────
FROM development AS builder

COPY . .
RUN npm run build

# ── Production ────────────────────────────────────────────────────────────────
FROM nginx:alpine AS production

COPY --from=builder /app/dist /usr/share/nginx/html
COPY infra/nginx/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
