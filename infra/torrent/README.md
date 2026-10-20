# torrent

qBittorrent, il client torrent del server. La dashboard ron1nOS lo usa
tramite la sua Web API (modulo Download, specifica nel repo ron1nOS in
`docs/specs/downloads.md`).

## Primo avvio

```sh
cd /opt/ron1n/infra/torrent
cp .env.example .env            # PUID/PGID da `id`, cartella download
sudo mkdir -p /srv/downloads && sudo chown 1000:1000 /srv/downloads
docker compose up -d
docker compose logs qbittorrent | grep -i password
```

Il log stampa una password temporanea per l'utente `admin`. Apri
`https://torrent.ron1n.home` (via Tailscale) e in Strumenti → Opzioni →
Web UI:

1. **Autenticazione:** cambia utente e password (se non la cambi, a ogni
   riavvio ne viene generata una nuova). Salvale nel password manager e
   nel `.env` della dashboard, mai in git.
2. **Non attivare** "Salta l'autenticazione per i client in localhost" né
   la whitelist di sottoreti: sulla rete `proxy` ci sono altri container.
3. Lascia attive la protezione CSRF, il clickjacking e la validazione
   dell'header Host.
4. **Supporto reverse proxy:** attivalo e indica come proxy fidato la
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
