FROM node:18 AS builder
WORKDIR /builder
COPY package-lock.json  package.json .
RUN npm install
COPY . .
# "POST /undefined/guess/123 HTTP/1.1" 405 559
# need to add `api`
ENV REACT_APP_BACKEND_URL=/api
RUN npm run build

# --- Runtime image: nginx + react
FROM nginx:alpine-slim
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /builder/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]