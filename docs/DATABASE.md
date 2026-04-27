# Database Documentation

The project uses a containerized **MySQL 8.0** database to store the e-commerce catalog.

## Initialization

The database is automatically initialized the very first time the `ecommerce-db` Docker container boots. It uses standard Docker initialization by running the `.sql` scripts located in `ecommerce-app/docker/db/init/`.

1. **`01-create-user.sql`**: Creates the database `full-stack-ecommerce` and a dedicated user `ecommerceapp` (instead of using the root user).
2. **`02-create-products.sql`**: Creates the schema tables and inserts 100 sample products across 5 categories.

## Schema Overview

**Database Name:** `full-stack-ecommerce`

### Table: `product_category`
Stores the categories that products belong to.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique category ID |
| `category_name` | VARCHAR(255) | | Name of the category (e.g., "Books") |

### Table: `product`
Stores individual product details.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique product ID |
| `sku` | VARCHAR(255) | | Stock Keeping Unit |
| `name` | VARCHAR(255) | | Product name |
| `description` | VARCHAR(255) | | Product description |
| `unit_price` | DECIMAL(13,2) | | Price of the product |
| `image_url` | VARCHAR(255) | | Path to the product image asset |
| `active` | BIT | | 1 if active, 0 if inactive |
| `units_in_stock` | INT | | Inventory count |
| `date_created` | DATETIME(6) | | Timestamp of creation |
| `last_updated` | DATETIME(6) | | Timestamp of last modification |
| `category_id` | BIGINT | FOREIGN KEY (`product_category.id`) | Associates product to a category |

## Persistence

Data is persisted on the VM using a Docker Named Volume (`mysql-data`).
If you need to completely wipe and reset the database, you must destroy the volume:
```bash
docker compose down -v
```
