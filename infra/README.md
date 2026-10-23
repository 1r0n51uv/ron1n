# infra

Uno stack Docker Compose per cartella. Sul server il repo è clonato in
`/opt/ron1n`.

| Stack        | Contenuto                                                                                      |
| ------------ | ---------------------------------------------------------------------------------------------- |
| `proxy`      | Caddy, reverse proxy per tutti i servizi web                                                   |
| `dns`        | CoreDNS, i nomi `*.ron1n.home` per i client della tailnet ([README](dns/README.md))            |
| `monitoring` | Uptime Kuma                                                                                    |
| `updates`    | Watchtower, aggiorna solo i container con l'etichetta di opt-in                                |
| `torrent`    | qBittorrent, client torrent usato dal modulo Download di ron1nOS ([README](torrent/README.md)) |
| `glances`    | Glances, risorse del server per il modulo Server di ron1nOS ([README](glances/README.md))      |
| `postgres`   | Postgres condiviso dalle app ([README](postgres/README.md))                                    |
| `ron1nos`    | Dashboard ron1nOS su `ron1n.home` ([README](ron1nos/README.md))                                |
| `ios`        | Build delle app iOS con xtool e pagina `ios.ron1n.home` ([README](ios/README.md))              |

## Avvio e spegnimento

Tutti gli stack si gestiscono con [`infra.sh`](../infra.sh), dalla radice
del repo (con `sudo` se il repo è di root, come in `/opt/ron1n`):

```sh
./infra.sh up              # avvia tutto, anche la prima volta
./infra.sh down            # spegne tutto; volumi, .env e reti restano
./infra.sh status          # container di ogni stack
./infra.sh up torrent      # solo gli stack indicati
```

Al primo avvio `up` crea le reti `proxy` e `db`, i `.env` mancanti da
`.env.example` con password casuali (le stesse dove servono in due stack,
come Postgres e ron1nOS) e la cartella dei download. Un `.env` esistente non
viene mai toccato: per cambiare una password modifica il `.env` e rilancia
`up` (la password di un database già creato va cambiata anche in Postgres,
vedi il suo [README](postgres/README.md)).

L'ordine di avvio è in `ORDER` dentro lo script: Postgres per primo,
Caddy per ultimo; `down` va al contrario. Uno stack nuovo parte dopo gli
altri senza toccare lo script; se ha un `.env.example` e il `.env` non c'è,
non viene avviato finché non lo crei. Specifica:
[`docs/specs/infra.md`](../docs/specs/infra.md).

## Aggiungere un servizio

1. Crea `infra/<nome>/compose.yaml` e collega il servizio alla rete `proxy`.
   Se dipende da altri stack o deve partire prima, aggiungilo a `ORDER` in
   [`infra.sh`](../infra.sh); se il suo `.env` ha password, aggiungi la
   generazione in `make_envs`.
2. Aggiungi un blocco in `proxy/Caddyfile`, poi
   `docker compose -f proxy/compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile`.
3. Per le immagini delle tue app su GHCR parti da
   [`_app-template/compose.yaml`](_app-template/compose.yaml): ha già
   l'etichetta `com.centurylinklabs.watchtower.enable: "true"`, così
   Watchtower le aggiorna (vedi [flusso di sviluppo](../docs/flusso-sviluppo.md)).
