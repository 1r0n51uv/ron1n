# ron1nos

La dashboard [ron1nOS](https://github.com/1r0n51uv/ron1nOS): un container
Node che serve l'interfaccia web e l'API `/api/v1`, la stessa che userà
l'app iOS.

## Primo avvio

Servono gli stack `torrent`, con le credenziali della Web UI, e
`postgres`, con il database `ron1nos` (vedi [README](../postgres/README.md)).

```sh
cd /opt/ron1n/infra/ron1nos
cp .env.example .env            # credenziali di torrent e DATABASE_URL di postgres
docker compose up -d
docker compose ps               # lo stato diventa healthy
```

Poi apri `https://home.ron1n.space` (Cloudflare Access chiede il codice via mail). Per collegare YAZIO al
modulo Nutrizione togli il commento alle variabili `YAZIO_*` nel `.env`,
`docker compose up -d`, poi in Impostazioni › YAZIO premi Sincronizza ora.

## Dati

Il volume `workout-catalog` tiene la copia delle foto degli esercizi
(free-exercise-db, modulo Allenamento): il container la scarica da GitHub
al primo avvio e poi la serve dal disco. Se si cancella, si riscarica da
sola.

## Aggiornamenti

L'immagine `:main` viene pubblicata su GHCR a ogni merge su main e
Watchtower la aggiorna da solo. Per tornare indietro si fissa in
`compose.yaml` un tag `:sha-<commit>` e si esegue `docker compose up -d`.
Se il pacchetto GHCR è privato, Watchtower ha bisogno delle credenziali:
vedi `updates/compose.yaml`.

## Rete

- La porta 8080 non è pubblicata sull'host: la raggiunge solo Caddy.
- qBittorrent risponde come `qbittorrent:8080` sulla rete `proxy`.
- Postgres risponde come `postgres:5432` sulla rete `db`.
- `host.docker.internal` porta all'host, per i servizi in rete host come
  Glances (modulo Server, `172.17.0.1:61208`).
