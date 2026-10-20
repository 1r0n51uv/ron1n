# CLAUDE.md

Contesto per le sessioni di Claude che lavorano su questo repo.

- ron1n è un hub: qui stanno README, documentazione e `infra/` dell'home
  server. Il codice delle app va nei loro repo (vedi la tabella nel README).
- Documentazione e commenti in italiano.
- Ogni servizio del server è uno stack in `infra/<nome>/compose.yaml`.
  Gli stack esposti via web si collegano alla rete Docker esterna `proxy`
  e vengono pubblicati da Caddy (`infra/proxy/Caddyfile`), mai con `ports:`
  propri sulla 80/443.
- Segreti solo in file `.env` non versionati; versiona un `.env.example`.
- Immagini sempre con tag esplicito; niente `latest` per i servizi con dati.
- Accesso privato via Tailscale, pubblico solo via Cloudflare Tunnel.
- Flusso di sviluppo delle app (specifica → issue con label → PR con CI →
  immagine GHCR → Watchtower): `docs/flusso-sviluppo.md`. Il template per un
  nuovo repo app è in `templates/app/`.
