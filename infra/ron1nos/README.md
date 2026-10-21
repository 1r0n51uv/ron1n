# ron1nos

La dashboard [ron1nOS](https://github.com/1r0n51uv/ron1nOS): un container
Node che serve l'interfaccia web e l'API `/api/v1`, la stessa che userà
l'app iOS.

## Primo avvio

Serve lo stack `torrent` già avviato, con le credenziali della Web UI.

```sh
cd /opt/ron1n/infra/ron1nos
cp .env.example .env            # stesse credenziali del .env di torrent
docker compose up -d
docker compose ps               # lo stato diventa healthy
```

Poi apri `https://ron1n.home` via Tailscale.

## Aggiornamenti

L'immagine `:main` viene pubblicata su GHCR a ogni merge su main e
Watchtower la aggiorna da solo. Per tornare indietro si fissa in
`compose.yaml` un tag `:sha-<commit>` e si esegue `docker compose up -d`.
Se il pacchetto GHCR è privato, Watchtower ha bisogno delle credenziali:
vedi `updates/compose.yaml`.

## Rete

- La porta 8080 non è pubblicata sull'host: la raggiunge solo Caddy.
- qBittorrent risponde come `qbittorrent:8080` sulla rete `proxy`.
- `host.docker.internal` porta all'host, per i servizi in rete host come
  Glances (modulo Server, `172.17.0.1:61208`).
