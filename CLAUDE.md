# CLAUDE.md

Contesto per le sessioni di Claude che lavorano su questo repo.

- ron1n è un hub: qui stanno README, documentazione e `infra/` dell'home
  server. Il codice delle app va nei loro repo (vedi la tabella nel README).
- Documentazione e commenti in italiano.
- Ogni servizio del server è uno stack in `infra/<nome>/compose.yaml`.
  Gli stack esposti via web si collegano alla rete Docker esterna `proxy`
  e vengono pubblicati da Caddy (`infra/proxy/Caddyfile`), mai con `ports:`
  propri sulla 80/443.
- Tutti gli stack si avviano e spengono con `./infra.sh up|down|status`
  (spec `docs/specs/infra.md`): uno stack nuovo con dipendenze va in `ORDER`,
  le sue password generate in `make_envs`.
- Segreti solo in file `.env` non versionati; versiona un `.env.example`.
- Immagini sempre con tag esplicito; niente `latest` per i servizi con dati.
- Accesso privato via Tailscale, pubblico solo via Cloudflare Tunnel.
- Flusso di sviluppo delle app (specifica → issue con label → PR con CI →
  immagine GHCR → Watchtower): `docs/flusso-sviluppo.md`. Il template per un
  nuovo repo app è in `templates/app/`.
- Prima di consegnare: `npm run check` pulito (Prettier, markdownlint,
  shellcheck e test di `infra.sh`, validazione di `infra/`). La CI fa anche `caddy validate` e actionlint.
- Le regole di lint, formato e test delle app sono in
  `docs/flusso-sviluppo.md` e la configurazione in `templates/app/`:
  se cambiano, aggiorna entrambi.
