# webtop

[Webtop](https://docs.linuxserver.io/images/docker-webtop/) di linuxserver:
un desktop Linux completo (Debian + XFCE, con Firefox, terminale e file
manager) che si apre da qualsiasi browser. Il server resta senza interfaccia
grafica, il desktop vive solo in questo container.

## Primo avvio

```sh
cd /opt/ron1n/infra/webtop
cp .env.example .env            # PUID/PGID da `id`, utente e password
docker compose up -d
```

Poi ricarica Caddy (vedi `infra/README.md`) e apri
`https://desktop.ron1n.home` dalla tailnet. Il browser chiede utente e
password del `.env`, poi mostra il desktop XFCE.

Il primo avvio scarica un'immagine di circa 1,5 GB e prepara la home: serve
qualche minuto. A regime il desktop occupa 1-2 GB di RAM, di più con molte
schede aperte.

## Dati

- La home dell'utente (`/config` nel container) sta nel volume
  `webtop_config`: impostazioni, segnalibri e file scaricati restano tra un
  riavvio e l'altro.
- Il resto del container si ricrea a ogni aggiornamento: programmi
  installati con `apt` spariscono. Per averli sempre si usa un
  [mod di linuxserver](https://mods.linuxserver.io/) o uno script in
  `/custom-cont-init.d`, come nello stack `torrent`.
- Per vedere da qui i download di qBittorrent si può montare
  `/srv/downloads` in `compose.yaml`, per esempio in sola lettura su
  `/config/Downloads/torrent`.

## Sicurezza

- Nessuna porta sull'host: la raggiunge solo Caddy, e Caddy solo la
  tailnet. **Mai via Cloudflare Tunnel**: chi entra nel desktop ha un
  terminale con `sudo` senza password dentro il container.
- Utente e password (`CUSTOM_USER`, `PASSWORD`) proteggono l'accesso anche
  da altri dispositivi della tailnet. Per cambiarli si modifica il `.env` e
  si fa `docker compose up -d`.
- Il container non ha il socket Docker né cartelle dell'host: dal desktop
  non si controlla il server.
- Se un browser dentro il desktop non parte o si chiude subito, la
  soluzione documentata è `security_opt: [seccomp:unconfined]` nel
  servizio. Toglie un livello di isolamento: aggiungilo solo se serve.

## Prestazioni

Lo streaming del desktop usa la CPU. Per alleggerirla si può passare la GPU
integrata del Ryzen al container con `devices: [/dev/dri:/dev/dri]`, da
provare una volta sul server.

## Aggiornamenti

Tag fisso, Watchtower non lo tocca. linuxserver pubblica una build a
settimana (`debian-xfce-<versione>-ls<N>`): per aggiornare si cambia il tag
in `compose.yaml` in una PR, poi `docker compose pull && docker compose up -d`.
