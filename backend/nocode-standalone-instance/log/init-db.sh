#!/bin/bash
set -e

# Define database configuration paths
POSTGRES_CONF_FILE="/var/lib/postgresql/data/postgresql.conf"

# Logging for initialization start
echo "Initializing PostgreSQL for main-log..."

# Check and configure logging_collector in postgresql.conf
if grep -q "^[#]*[[:space:]]*logging_collector[[:space:]]*=" "$POSTGRES_CONF_FILE"; then
  echo "Found logging_collector setting, updating it to 'on'."
  sed -i "s/^[#]*[[:space:]]*logging_collector[[:space:]]*=.*/logging_collector = on/" "$POSTGRES_CONF_FILE"
else
  echo "logging_collector setting not found, adding it."
  echo "logging_collector = on" >> "$POSTGRES_CONF_FILE"
fi

# Add custom logging configuration
if ! grep -q "log_directory" "$POSTGRES_CONF_FILE"; then
  echo "Configuring log_directory and log_filename in postgresql.conf..."
  echo "log_directory = 'pg_log'" >> "$POSTGRES_CONF_FILE"
  echo "log_filename = 'postgresql-%Y-%m-%d.log'" >> "$POSTGRES_CONF_FILE"
  echo "log_statement = 'all'" >> "$POSTGRES_CONF_FILE"
  echo "log_min_duration_statement = 0" >> "$POSTGRES_CONF_FILE"
fi

# Check if the database exists
DB_CHECK_QUERY="SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB';"
if psql -U "$POSTGRES_USER" -d postgres -tc "$DB_CHECK_QUERY" | grep -q 1; then
  echo "Database '$POSTGRES_DB' already exists. Skipping initialization."
else
  echo "Database '$POSTGRES_DB' does not exist. Creating database..."
  createdb -U "$POSTGRES_USER" -O "$POSTGRES_USER" "$POSTGRES_DB"
fi

# Logging for successful initialization
echo "PostgreSQL initialization for main-log is complete."
