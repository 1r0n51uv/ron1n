# postgres

Postgres condiviso dalle app ron1n (decisione 6 della
[specifica Nutrizione](https://github.com/1r0n51uv/ron1nOS/blob/main/docs/specs/nutrition.md#decisioni)):
un solo server, un database e un utente per app. Oggi c'è `ron1nos`, per il
modulo Nutrizione della dashboard.

## Primo avvio

```sh
docker network create db           # una volta sola
cd /opt/ron1n/infra/postgres
cp .env.example .env               # cambia tutte le password
docker compose up -d
docker compose ps                  # postgres diventa healthy
```

Lo script in `init/` crea utente e database `ron1nos` al primo avvio. Poi
nel `.env` di `infra/ron1nos`:

```sh
DATABASE_URL=postgres://ron1nos:<RON1NOS_DB_PASSWORD>@postgres:5432/ron1nos
```

Le tabelle le crea ron1nOS da solo all'avvio, con le sue migrazioni.

## Rete

- Nessuna porta sull'host: le app lo raggiungono come `postgres:5432`
  sulla rete esterna `db`, a cui si collega solo chi ha un database.
- Per una console: `docker compose exec postgres psql -U postgres`.

## Backup

Il container `backup` fa ogni notte alle 3:30 un `pg_dump` di ogni database
in `/srv/backups/postgres` (formato custom) più i ruoli
(`globals-*.sql`), e tiene gli ultimi 14 giorni. La cartella entra nel
backup del server (restic). Ripristino di un database:

```sh
docker compose exec -T postgres pg_restore -U postgres -d ron1nos --clean --if-exists \
  < /srv/backups/postgres/ron1nos-AAAAMMGG-HHMM.dump
```

## Nuova app

`init/` gira solo con il volume vuoto. Su un Postgres già avviato:

```sh
docker compose exec postgres psql -U postgres \
  -c "CREATE ROLE <app> LOGIN PASSWORD '<password>'" \
  -c "CREATE DATABASE <app> OWNER <app>"
```

Poi aggiungi uno script in `init/` per le installazioni nuove.

## Aggiornamenti

Il tag è fisso (`16.10-alpine`): Watchtower non lo tocca. Un aggiornamento
minore (16.x) basta cambiare il tag e `docker compose up -d`; uno maggiore
(17) richiede dump e ripristino.
