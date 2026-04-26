-- ============================================
-- Database User Creation (Docker-Modified)
-- ============================================
--
-- WHAT CHANGED FROM THE ORIGINAL:
--   Original: CREATE USER 'ecommerceapp'@'localhost'
--   Modified: CREATE USER 'ecommerceapp'@'%'
--
-- WHY:
--   In Docker, each service runs in its own container with its own IP.
--   The Spring Boot backend connects to MySQL from a different container,
--   so from MySQL's perspective the connection comes from a non-localhost IP.
--   The '%' wildcard means "accept connections from any host".
--
--   Without this change, the backend would get:
--   "Access denied for user 'ecommerceapp'@'172.18.0.3'"
-- ============================================

-- Create the application database user
-- Using '%' instead of 'localhost' to allow connections from Docker containers
CREATE USER IF NOT EXISTS 'ecommerceapp'@'%' IDENTIFIED BY 'ecommerceapp';

GRANT ALL PRIVILEGES ON *.* TO 'ecommerceapp'@'%';

--
-- Starting with MySQL 8.0.4, the MySQL team changed the
-- default authentication plugin for MySQL server
-- from mysql_native_password to caching_sha2_password.
--
-- The command below will make the appropriate updates for your user account.
--
-- See the MySQL Reference Manual for details:
-- https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html
--
ALTER USER 'ecommerceapp'@'%' IDENTIFIED WITH mysql_native_password BY 'ecommerceapp';

FLUSH PRIVILEGES;
