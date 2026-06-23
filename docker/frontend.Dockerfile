FROM node:18 AS builder
WORKDIR /builder
COPY package-lock.json  package.json .
RUN npm install
COPY . .
RUN npm run build

# --- Runtime image
FROM nginx:alpine-slim
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /builder/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]