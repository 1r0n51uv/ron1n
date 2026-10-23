# tunnel

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
porta i siti del server su `*.ron1n.space`, da ogni rete e senza VPN.
`cloudflared` apre una connessione in uscita verso Cloudflare, che riceve le
richieste e le passa a Caddy (`http://caddy:80`, rete `proxy`). Davanti a
tutti i nomi c'è Cloudflare Access: chi non è autorizzato si ferma lì.
Specifica: SETUP-008 in
[`docs/specs/server-setup.md`](../../docs/specs/server-setup.md).

## Configurazione

`TUNNEL_TOKEN` in `.env`: lo chiede il bootstrap, oppure lo copi a mano e
rilanci `sudo ./infra.sh up tunnel`. Senza token lo stack non parte.

Il tunnel, il suo hostname e Access si creano nella dashboard di
Cloudflare: i passi sono in [`docs/server-setup.md`](../../docs/server-setup.md#accesso-da-fuori-con-cloudflare).
Quale sito risponde a quale nome lo decide Caddy, in
[`infra/proxy/Caddyfile`](../proxy/Caddyfile).

## Protocollo

Il tunnel usa HTTP/2 su TCP (`--protocol http2`), non QUIC, il default di
`cloudflared`. Con QUIC, su UDP, due delle quattro connessioni (quelle
verso Roma) restavano appese: le richieste che ci capitavano aspettavano
da qualche secondo a un minuto, mentre il backend rispondeva in pochi
millisecondi. Nei log `cloudflared` si vedeva
`Incoming request ended abruptly: context canceled`.

## Limiti

Il piano gratuito accetta richieste fino a 100 MB: un upload più grande
(documenti, file) si ferma a Cloudflare.
