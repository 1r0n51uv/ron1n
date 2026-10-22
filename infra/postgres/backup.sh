#!/bin/sh
# Dump di ogni database ogni notte alle 3:30 (ora del container, UTC se non
# impostata), in formato custom di pg_dump: si ripristina con pg_restore.
set -eu

while true; do
  now=$(date +%s)
  next=$(date -d "$(date +%Y-%m-%d) 03:30" +%s 2>/dev/null || echo $((now + 86400)))
  [ "$next" -le "$now" ] && next=$((next + 86400))
  sleep $((next - now))

  stamp=$(date +%Y%m%d-%H%M)
  for db in $(psql -Atc "select datname from pg_database where not datistemplate and datname <> 'postgres'"); do
    if pg_dump -Fc -f "/backups/$db-$stamp.dump" "$db"; then
      echo "dump di $db ok"
    else
      echo "dump di $db non riuscito" >&2
      rm -f "/backups/$db-$stamp.dump"
    fi
  done
  pg_dumpall --globals-only >"/backups/globals-$stamp.sql"
  find /backups -type f -mtime +"$BACKUP_KEEP_DAYS" -delete
done
