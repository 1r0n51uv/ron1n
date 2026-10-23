# glances

[Glances](https://github.com/nicolargo/glances) legge le risorse del server
(CPU, RAM, dischi, rete, temperature, consumo per container) e le espone con
un'API REST. La dashboard ron1nOS la usa per il modulo Server (specifica nel
repo ron1nOS in `docs/specs/server.md`).

## Avvio

```sh
cd /opt/ron1n/infra/glances
docker compose up -d
curl -s http://172.17.0.1:61208/api/4/quicklook   # dal server
```

Poi ricarica Caddy (vedi `infra/README.md`) e apri
`https://glances.ron1n.space` (dietro Cloudflare Access) per l'interfaccia web.

## Primo controllo

Al primo avvio verifica nell'interfaccia web che:

- **Temperature:** compaia il sensore della CPU (`k10temp`, voce `Tctl`).
  Se manca, sull'host `sudo apt install lm-sensors && sudo sensors-detect`.
- **Dischi:** compaia `/rootfs` con lo spazio del disco di sistema, e
  nessuna voce inutile. Altrimenti si corregge `hide` in `[fs]`.
- **Rete:** compaia solo l'interfaccia fisica (`enp…` o simile).
- **Container:** compaiano tutti i container con CPU e memoria.

## Rete

- `network_mode: host` e `pid: host` servono a leggere rete e processi
  dell'host. Per questo il container non si collega alla rete `proxy`.
- Glances ascolta solo su `172.17.0.1:61208`, l'IP dell'host sul bridge
  `docker0`. Lo raggiungono i container (Caddy e ron1nOS lo chiamano
  `host.docker.internal`), non la LAN direttamente.
- L'interfaccia web passa dal tunnel e da Caddy su `glances.ron1n.space`,
  sempre dietro Cloudflare Access: l'API non ha login e mostra l'elenco
  dei processi con le loro righe di comando.
- In `glances.conf` l'API accetta solo gli Host `glances.ron1n.space`,
  `host.docker.internal` e `172.17.0.1` (gli altri ricevono `400`) e nessuna
  origine cross-site, così una pagina web qualsiasi non può leggerla.
- Se `docker0` avesse un altro indirizzo (`ip -4 addr show docker0`),
  aggiorna `--bind` in `compose.yaml`.

## Socket Docker

Il consumo per container richiede il socket Docker. Il `:ro` impedisce di
cancellare il file, non di usare l'API: chi controlla Glances controlla
Docker. È accettato perché Glances non è raggiungibile da fuori del server.
Un rafforzamento possibile, da decidere insieme al modulo container di
ron1nOS, è un `docker-socket-proxy` che concede solo le letture.

## Aggiornamenti

Tag fisso, Watchtower non lo tocca. Per aggiornare si cambia il tag in
`compose.yaml` in una PR, poi `docker compose pull && docker compose up -d`.
