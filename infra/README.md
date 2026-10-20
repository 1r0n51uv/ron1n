# infra

Uno stack Docker Compose per cartella. Sul server il repo è clonato in
`/opt/ron1n`.

| Stack | Contenuto |
|---|---|
| `proxy` | Caddy, reverse proxy per tutti i servizi web |
| `monitoring` | Uptime Kuma |
| `updates` | Watchtower, aggiorna solo i container con l'etichetta di opt-in |

## Avvio

```sh
docker network create proxy        # una volta sola
cd /opt/ron1n/infra/proxy && docker compose up -d
cd ../monitoring && docker compose up -d
cd ../updates && docker compose up -d
```

## Aggiungere un servizio

1. Crea `infra/<nome>/compose.yaml` e collega il servizio alla rete `proxy`.
2. Aggiungi un blocco in `proxy/Caddyfile`, poi
   `docker compose -f proxy/compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile`.
3. Per le immagini delle tue app su GHCR, aggiungi
   `com.centurylinklabs.watchtower.enable: "true"` così Watchtower le aggiorna.

## Spostare 1r0-pkm da EC2

Il compose di 1r0-pkm include un suo Caddy sulla 80/443, che qui va in
conflitto. Sul server si avviano solo `db` e `api`, con `api` collegata alla
rete `proxy`; il dominio pubblico passa da Cloudflare Tunnel. Prima di
spegnere EC2: `pg_dump` dei due database e ripristino sul nuovo Postgres.
