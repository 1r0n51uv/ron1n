# Caddy con il plugin DNS di Cloudflare, per i certificati Let's Encrypt
# con la verifica DNS-01 (SETUP-008). Versioni fisse: cambiale insieme al
# tag dell'immagine in compose.yaml e a CADDY_VERSION della CI.
ARG CADDY_VERSION=2.10.2

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder
ARG CADDY_DNS_CLOUDFLARE=v0.2.4
RUN xcaddy build --with github.com/caddy-dns/cloudflare@${CADDY_DNS_CLOUDFLARE}

FROM caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
