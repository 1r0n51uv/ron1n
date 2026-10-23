# proxy

Caddy smista per nome tutti i siti del server. Gli arrivano solo dal
tunnel ([`infra/tunnel`](../tunnel/README.md)) e solo in HTTP: HTTPS,
certificati e login li fa Cloudflare. Non pubblica porte sull'host.

`DOMINIO` in `.env` è il dominio dei siti (`ron1n.space`). Un sito nuovo è
un blocco `@nome host nome.{$DOMINIO}` + `handle` nel
[`Caddyfile`](Caddyfile); poi ricarica Caddy:

```sh
docker compose -f infra/proxy/compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Il nome è già coperto dall'hostname wildcard del tunnel e da Access.
