# dns

[CoreDNS](https://coredns.io) risponde a ogni nome `*.ron1n.home` con l'IP
Tailscale del server, dove Caddy smista i siti per nome. Così i client
della tailnet, iPhone compreso, aprono `https://ron1n.home` senza toccare
il file hosts. Specifica: SETUP-005 in
[`docs/specs/server-setup.md`](../../docs/specs/server-setup.md).

## Configurazione

`TS_IP` in `.env` è l'IP del server nella tailnet (`tailscale ip -4`).
`./infra.sh up` e il bootstrap lo scrivono da soli; se cambia, correggilo e
rilancia `sudo ./infra.sh up dns`.

Poi, una volta sola, nella [console Tailscale](https://login.tailscale.com/admin/dns):
**DNS → Nameservers → Add nameserver → Custom**, indirizzo = `TS_IP`, attiva
**Restrict to domain** e scrivi `ron1n.home`. I client con "Use Tailscale
DNS" attivo (il default su iPhone, Mac e Windows) mandano qui solo le
domande su `ron1n.home`; il resto va al DNS di sempre.

## Prova

```sh
dig @100.x.y.z torrent.ron1n.home +short   # dall'IP del server: TS_IP
```

## Rete

Pubblica la porta 53 (UDP e TCP) dell'host. Il firewall del bootstrap la
chiude dalla LAN e da internet (catena `DOCKER-USER`): risponde solo alla
tailnet.
