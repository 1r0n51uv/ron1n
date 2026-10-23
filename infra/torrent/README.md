# torrent

qBittorrent, il client torrent del server. La dashboard ron1nOS lo usa
tramite la sua Web API (modulo Download, specifica nel repo ron1nOS in
`docs/specs/downloads.md`).

## Primo avvio

```sh
cd /opt/ron1n/infra/torrent
cp .env.example .env            # PUID/PGID da `id`, cartella download, credenziali
sudo mkdir -p /srv/downloads && sudo chown 1000:1000 /srv/downloads
docker compose up -d
docker compose logs qbittorrent | grep webui-credentials
```

Utente e password della Web UI vengono da `QBT_USERNAME` e `QBT_PASSWORD`
nel `.env` (default `admin`/`admin`). Lo script
[`init/10-webui-credentials`](init/10-webui-credentials) li scrive in
`qBittorrent.conf` a ogni avvio, come hash PBKDF2: per cambiarli si
modifica il `.env` e si riavvia il container. Una password cambiata dalla
Web UI viene sovrascritta al riavvio successivo. Lo script deve restare
eseguibile e di proprietà di root, altrimenti l'immagine lo salta.

Apri `https://torrent.home.ron1n.space` (via Tailscale) e in Strumenti → Opzioni
→ Web UI:

1. **Non attivare** "Salta l'autenticazione per i client in localhost" né
   la whitelist di sottoreti: sulla rete `proxy` ci sono altri container.
2. Lascia attive la protezione CSRF, il clickjacking e la validazione
   dell'header Host.
3. **Supporto reverse proxy:** attivalo e indica come proxy fidato la
   sottorete della rete `proxy` (`docker network inspect proxy`), così
   qBittorrent vede l'IP vero del client e il ban dopo troppi login
   falliti colpisce il client giusto.

In Opzioni → Download imposta la cartella predefinita a `/downloads`.

## Rete

- La Web UI (8080) non è pubblicata sull'host: la raggiunge solo Caddy, e
  Caddy è raggiungibile solo dalla tailnet. Non va esposta via Cloudflare
  Tunnel.
- La porta BitTorrent (`TORRENTING_PORT`, default 6881) è pubblicata su
  TCP e UDP. Inoltrala sul router per accettare connessioni in ingresso;
  senza inoltro funziona comunque, con meno peer.
- Il traffico BitTorrent esce con l'IP di casa. Una VPN (per esempio un
  container gluetun con `network_mode: service:gluetun`) è un'aggiunta
  possibile, da decidere a parte.

## Aggiornamenti

Il tag è fisso, Watchtower non lo tocca. Per aggiornare si cambia il tag
in `compose.yaml` in una PR, poi `docker compose pull && docker compose up -d`.
