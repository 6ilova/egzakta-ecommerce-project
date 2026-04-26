# ============================================
# Database Dockerfile — MySQL 8.0
# ============================================
#
# WHY a custom Dockerfile instead of just using mysql:8.0 in compose:
#   We need to seed the database with schema and sample data on first boot.
#   MySQL's official image executes all .sql files in /docker-entrypoint-initdb.d/
#   in alphabetical order when the data volume is empty (first run only).
#
# WHY we have a modified 01-create-user.sql:
#   The original SQL from the e-commerce repo creates the user with:
#     CREATE USER 'ecommerceapp'@'localhost'
#   In Docker, the backend connects from a DIFFERENT container (different IP).
#   MySQL's 'localhost' means "same machine only" — it would reject the
#   backend's connection. We change it to '%' (any host).
#
# WHY we copy 02-create-products.sql from the cloned repo:
#   This file contains the full schema + 100 sample products. It's large
#   and unchanged, so we reference the original from backend/sql-resources/
#   instead of duplicating it.
#
# BUILD CONTEXT: Must be the project root (not this directory)
# ============================================

FROM mysql:8.0

# Copy our modified user creation script (uses '%' wildcard host)
COPY docker/db/init/01-create-user.sql /docker-entrypoint-initdb.d/01-create-user.sql

# Copy the original products/schema SQL directly from the cloned repo
COPY backend/sql-resources/02-create-products.sql /docker-entrypoint-initdb.d/02-create-products.sql

# Default environment variables — overridden by docker-compose.yml
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=full-stack-ecommerce
