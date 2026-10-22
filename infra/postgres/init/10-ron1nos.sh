#!/bin/sh
# Utente e database di ron1nOS. Gira solo al primo avvio, con il volume
# vuoto; su un Postgres già inizializzato vedi README, "Nuova app".
set -eu

psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -v pw="$RON1NOS_DB_PASSWORD" <<'SQL'
CREATE ROLE ron1nos LOGIN PASSWORD :'pw';
CREATE DATABASE ron1nos OWNER ron1nos;
REVOKE ALL ON DATABASE ron1nos FROM PUBLIC;
SQL
