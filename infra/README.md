# infra

Uno stack Docker Compose per cartella. Sul server il repo è clonato in
`/opt/ron1n`.

| Stack        | Contenuto                                                                                      |
| ------------ | ---------------------------------------------------------------------------------------------- |
| `proxy`      | Caddy, reverse proxy per tutti i servizi web                                                   |
| `monitoring` | Uptime Kuma                                                                                    |
| `updates`    | Watchtower, aggiorna solo i container con l'etichetta di opt-in                                |
| `torrent`    | qBittorrent, client torrent usato dal modulo Download di ron1nOS ([README](torrent/README.md)) |
| `glances`    | Glances, risorse del server per il modulo Server di ron1nOS ([README](glances/README.md))      |
| `postgres`   | Postgres condiviso dalle app ([README](postgres/README.md))                                    |
| `ron1nos`    | Dashboard ron1nOS su `ron1n.home` ([README](ron1nos/README.md))                                |
| `webtop`     | Desktop Linux (Debian + XFCE) nel browser su `desktop.ron1n.home` ([README](webtop/README.md)) |

## Avvio

```sh
docker network create proxy        # una volta sola
docker network create db           # una volta sola
cd /opt/ron1n/infra/proxy && docker compose up -d
cd ../monitoring && docker compose up -d
cd ../updates && docker compose up -d
cd ../torrent && cp .env.example .env && docker compose up -d
cd ../glances && docker compose up -d
cd ../postgres && cp .env.example .env   # cambia le password, poi docker compose up -d
cd ../ron1nos && cp .env.example .env && docker compose up -d
cd ../webtop && cp .env.example .env   # cambia la password, poi docker compose up -d
```

## Aggiungere un servizio

1. Crea `infra/<nome>/compose.yaml` e collega il servizio alla rete `proxy`.
2. Aggiungi un blocco in `proxy/Caddyfile`, poi
   `docker compose -f proxy/compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile`.
3. Per le immagini delle tue app su GHCR parti da
   [`_app-template/compose.yaml`](_app-template/compose.yaml): ha già
   l'etichetta `com.centurylinklabs.watchtower.enable: "true"`, così
   Watchtower le aggiorna (vedi [flusso di sviluppo](../docs/flusso-sviluppo.md)).
