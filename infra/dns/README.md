# dns

[CoreDNS](https://coredns.io) risponde a ogni nome `*.home.ron1n.space` con l'IP
Tailscale del server, dove Caddy smista i siti per nome. Così i client
della tailnet, iPhone compreso, aprono `https://home.ron1n.space` senza toccare
il file hosts. Specifica: SETUP-005 in
[`docs/specs/server-setup.md`](../../docs/specs/server-setup.md).

## Configurazione

`TS_IP` in `.env` è l'IP del server nella tailnet (`tailscale ip -4`) e
`DOMINIO` la zona, la stessa di `infra/proxy/.env` (SETUP-008).
`./infra.sh up` e il bootstrap lo scrivono da soli; se cambia, correggilo e
rilancia `sudo ./infra.sh up dns`.

Poi, una volta sola, nella [console Tailscale](https://login.tailscale.com/admin/dns):
**DNS → Nameservers → Add nameserver → Custom**, indirizzo = `TS_IP`, attiva
**Restrict to domain** e scrivi `home.ron1n.space`. I client con "Use Tailscale
DNS" attivo (il default su iPhone, Mac e Windows) mandano qui solo le
domande su `home.ron1n.space`; il resto va al DNS di sempre.

## Prova

```sh
dig @100.x.y.z torrent.home.ron1n.space +short   # dall'IP del server: TS_IP
```

## Rete

Pubblica la porta 53 (UDP e TCP) dell'host. Il firewall del bootstrap la
chiude dalla LAN e da internet (catena `DOCKER-USER`): risponde solo alla
tailnet.
