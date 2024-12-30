#!/bin/bash
set -e

echo "Starting PostgreSQL main database initialization..."

POSTGRES_CONF_FILE="/var/lib/postgresql/data/postgresql.conf"

# 检查并配置 logging_collector
if grep -q "^[#]*[[:space:]]*logging_collector[[:space:]]*=" "$POSTGRES_CONF_FILE"; then
  echo "Found logging_collector setting, updating it to 'off'."
  sed -i "s/^[#]*[[:space:]]*logging_collector[[:space:]]*=.*/logging_collector = off/" "$POSTGRES_CONF_FILE"
else
  echo "logging_collector setting not found, adding it."
  echo "logging_collector = off" >> "$POSTGRES_CONF_FILE"
fi

# 检查数据库是否存在
DB_CHECK_QUERY="SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB';"
if psql -U "$POSTGRES_USER" -d postgres -tc "$DB_CHECK_QUERY" | grep -q 1; then
  echo "Database '$POSTGRES_DB' already exists."
else
  echo "Database '$POSTGRES_DB' does not exist. Initializing database..."
  createdb -U "$POSTGRES_USER" -O "$POSTGRES_USER" "$POSTGRES_DB"
fi

# 检查用户是否存在
USER_CHECK_QUERY="SELECT 1 FROM pg_roles WHERE rolname = 'codera-user';"
if psql -U "$POSTGRES_USER" -d postgres -tc "$USER_CHECK_QUERY" | grep -q 1; then
  echo "Replication user 'codera-user' already exists."
else
  echo "Replication user 'codera-user' does not exist. Creating user..."
  psql -U "$POSTGRES_USER" -d postgres -c "CREATE ROLE \"codera-user\" REPLICATION LOGIN PASSWORD 'codera12345!';"
fi



# 配置 postgresql.conf
if ! grep -q "wal_level = replica" "$POSTGRES_CONF_FILE"; then
  echo "Configuring wal_level, max_wal_senders, and wal_keep_size in postgresql.conf..."
  echo "wal_level = replica" >> "$POSTGRES_CONF_FILE"
  echo "max_wal_senders = 10" >> "$POSTGRES_CONF_FILE"
  echo "wal_keep_size = 64" >> "$POSTGRES_CONF_FILE"
else
  echo "Replication settings already configured in postgresql.conf."
fi

echo "PostgreSQL main database initialization complete."
