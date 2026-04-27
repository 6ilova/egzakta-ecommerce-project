# Frontend Dockerfile — Angular + Nginx (Multi-Stage)


# Build stage   
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FROM node:14-alpine AS build

WORKDIR /app

# Copy package files first — layer caching optimization.
COPY frontend/angular-ecommerce/package.json frontend/angular-ecommerce/package-lock.json ./


# npm install regenerates a compatible lock file from package.json.
RUN npm install --legacy-peer-deps

# Copy the rest of the Angular source
COPY frontend/angular-ecommerce/ .

# Build for production.
RUN npx ng build --prod




# Run stage
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FROM nginx:1.24-alpine

# Remove the default Nginx "Welcome" page config
RUN rm /etc/nginx/conf.d/default.conf

# Install our custom Nginx configuration (SPA routing + API proxy)
COPY docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf

# Copy the compiled Angular app from Stage 1.
COPY --from=build /app/dist/angular-ecommerce /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
