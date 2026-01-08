#!/usr/bin/env bash

set -e

display_usage() {
  echo "usage: $0 backup"
  echo "usage: $0 restore <filename>"
  echo "usage: $0 migrate <sql_file>"
  echo "usage: $0 psql"
}

backup_path="$HOME/backups/openworkers"

db_name=openworkers
db_user=openworkers
filename="$db_name-$(date +%Y-%m-%dT%H-%M-%S).dump"
container="openworkers-postgres-1"

operation=$1

if [ -z "$operation" ]; then
  display_usage
  exit 1
fi

shift

# Ensure backup directory exists
mkdir -p "$backup_path"

if [ "$operation" == "backup" ]; then
  echo "Dumping $db_name database from $container into $backup_path/$filename"

  docker exec "$container" pg_dump -U "$db_user" --format=custom --compress=9 "$db_name" > "$backup_path/$filename"

  echo "Backup completed: $backup_path/$filename"
  ls -lh "$backup_path/$filename"

elif [ "$operation" == "restore" ]; then
  filepath=$1

  if [ -z "$filepath" ]; then
    display_usage
    exit 1
  fi

  filename=$(basename "$filepath")
  echo "Restoring $filename"

  # Check if file exists
  if [ ! -f "$filepath" ]; then
    echo "File $filepath does not exist"
    exit 1
  fi

  docker cp "$filepath" "$container":/tmp/database.dump

  echo 'Create temporary database "tmp"'
  docker exec "$container" psql -U "$db_user" -c "CREATE DATABASE tmp"

  echo "Drop existing database \"$db_name\""
  docker exec "$container" psql -U "$db_user" -d tmp -c "DROP DATABASE IF EXISTS $db_name WITH (force)"

  echo "Recreate $db_name database"
  docker exec "$container" psql -U "$db_user" -d tmp -c "CREATE DATABASE $db_name"

  echo "Restore $db_name database"
  docker exec "$container" pg_restore -U "$db_user" -d "$db_name" /tmp/database.dump

  echo 'Remove "tmp" database'
  docker exec "$container" psql -U "$db_user" -c "DROP DATABASE IF EXISTS tmp"

  echo 'Restore completed'

elif [ "$operation" == "migrate" ]; then
  sql_file=$1

  if [ -z "$sql_file" ]; then
    display_usage
    exit 1
  fi

  if [ ! -f "$sql_file" ]; then
    echo "File $sql_file does not exist"
    exit 1
  fi

  filename=$(basename "$sql_file")
  echo "Running migration: $filename"

  docker cp "$sql_file" "$container":/tmp/migration.sql
  docker exec "$container" psql -U "$db_user" -d "$db_name" -f /tmp/migration.sql

  echo "Migration completed: $filename"

elif [ "$operation" == "psql" ]; then
  docker exec -it "$container" psql -U "$db_user" -d "$db_name"

else
  display_usage
  exit 1
fi
