
# Database Dockerfile — MySQL 8.0

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FROM mysql:8.0

# Copy our modified user creation script (uses '%' wildcard host)
COPY docker/db/init/01-create-user.sql /docker-entrypoint-initdb.d/01-create-user.sql

# Copy the original products/schema SQL directly from the cloned repo
COPY backend/sql-resources/02-create-products.sql /docker-entrypoint-initdb.d/02-create-products.sql

# Default environment variables — overridden by docker-compose.yml
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=full-stack-ecommerce
