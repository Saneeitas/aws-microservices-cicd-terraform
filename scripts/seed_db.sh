#!/usr/bin/env bash
# Create the `suppliers` table and the application DB user in database COFFEE.
#
# Columns come from services/*/app/models/supplier.model.js:
#   id, name, address, city, state, email, phone
# (the model does not define column types; VARCHAR(255) is used for the text columns).
# The app's config.js connects as user "nodeapp" / password "coffee" by default,
# so that user is created here too (sample/lab credentials; override in config via
# APP_DB_USER / APP_DB_PASSWORD env vars for anything real).
#
# The RDS instance is not publicly accessible: run this from a host that can reach
# port 3306 (inside the VPC, with an SG the DB SG allows).
#
# Usage:
#   DB_HOST=<endpoint> DB_ADMIN_PASSWORD=<master password> ./scripts/seed_db.sh
#   (or: DB_HOST=$(terraform -chdir=terraform output -raw db_endpoint))
set -euo pipefail

: "${DB_HOST:?set DB_HOST to the RDS endpoint}"
: "${DB_ADMIN_PASSWORD:?set DB_ADMIN_PASSWORD (the RDS master password)}"
DB_ADMIN_USER="${DB_ADMIN_USER:-admin}"
APP_USER="${APP_DB_USER:-nodeapp}"
APP_PASSWORD="${APP_DB_PASSWORD:-coffee}"

command -v mysql >/dev/null || { echo "ERROR: mysql client not found." >&2; exit 1; }

# MYSQL_PWD keeps the password off the process list.
MYSQL_PWD="${DB_ADMIN_PASSWORD}" mysql -h "${DB_HOST}" -u "${DB_ADMIN_USER}" <<SQL
CREATE DATABASE IF NOT EXISTS COFFEE;
USE COFFEE;

CREATE TABLE IF NOT EXISTS suppliers (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(255) NOT NULL,
  address VARCHAR(255),
  city    VARCHAR(255),
  state   VARCHAR(255),
  email   VARCHAR(255),
  phone   VARCHAR(255)
);

CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED BY '${APP_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON COFFEE.* TO '${APP_USER}'@'%';
FLUSH PRIVILEGES;
SQL

echo "Seeded COFFEE.suppliers and user '${APP_USER}' on ${DB_HOST}."
