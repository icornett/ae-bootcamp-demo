#!/usr/bin/env bash
# Creates multiple databases in a single postgres container on first boot.
# Referenced by POSTGRES_MULTIPLE_DATABASES env var (comma-separated).
set -e

create_db() {
  local db="$1"
  echo "Creating database '$db'..."
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
    SELECT 'CREATE DATABASE $db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
SQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
  for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
    create_db "$db"
  done
fi
