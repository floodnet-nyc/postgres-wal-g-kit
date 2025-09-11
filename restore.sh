#!/bin/bash
set -e

set_pg_conf() {
  local file="$1"
  local key="$2"
  local value="$3"

  # Escape slashes for sed
  local escaped_value
  escaped_value=$(printf '%s\n' "$value" | sed 's/[&/\]/\\&/g')

  # Does the key already exist (commented or uncommented)?
  local pattern="^[[:space:]]*#?[[:space:]]*$key[[:space:]]*="
  grep -Eq "$pattern" "$file" && sed -i -E "s|$pattern.*|$key = '$escaped_value'|" "$file" || (echo "$key = '$value'" >> "$file")
}




# If PGDATA is empty (no existing database), proceed to fetch backup
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "PGDATA is empty. Initiating WAL-G restore from backup..."
  mkdir -p "$PGDATA"

  # List available backups for logging/debugging
  echo "Available backups in WAL-G storage:"
  wal-g-env fetch backup-list --pretty --detail
  
  # Fetch the latest base backup using WAL-G
  wal-g-env fetch backup-fetch "$PGDATA" LATEST

  # After base backup is extracted, create recovery signal to trigger restore
  echo "Creating recovery.signal to start Postgres in recovery mode..."
  touch "$PGDATA/recovery.signal"

  # Configure postgresql.conf for archive_mode and restore_command
  if [ -z "$WALG_PUSH_PREFIX" ]; then
    set_pg_conf "$PGDATA/postgresql.conf" "archive_mode" "off"
  else
    set_pg_conf "$PGDATA/postgresql.conf" "archive_mode" "on"
  fi
  set_pg_conf "$PGDATA/postgresql.conf" "archive_command" "wal-g-env push wal-push \"%p\""
  set_pg_conf "$PGDATA/postgresql.conf" "restore_command" "wal-g-env fetch wal-fetch \"%f\" \"%p\""
  set_pg_conf "$PGDATA/postgresql.conf" "recovery_target_timeline" "latest"
  # Cleanup (stackgres)
  set_pg_conf "$PGDATA/postgresql.conf" "primary_slot_name" "backup_restore_test"

  cat "$PGDATA/postgresql.conf"

  chown -R postgres:postgres "$PGDATA"
  echo "Base backup fetched. WAL-G restore configured. Starting PostgreSQL..."

fi

# Start PostgreSQL server
postgres