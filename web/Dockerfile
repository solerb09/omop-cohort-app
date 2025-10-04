FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install --legacy-peer-deps --force && \
    npm install ajv@^8.12.0 --legacy-peer-deps --force

# Copy source code
COPY public ./public
COPY src ./src

# Build the app
ENV NODE_OPTIONS=--openssl-legacy-provider
RUN npm run build

# Production stage with nginx
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
