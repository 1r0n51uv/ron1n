# Changelog

Cosa cambia nel hub ron1n (documentazione, `infra/`, script del server), il
giorno più recente in alto. Ogni PR aggiunge la sua riga in cima, sotto il
giorno del merge ([flusso](docs/flusso-sviluppo.md#changelog)).

## 2026-10-28

- Novità di ogni versione nelle note di SideStore e CHANGELOG nei repo (IOSB-005) ([#67](https://github.com/1r0n51uv/ron1n/pull/67))
- Flusso: revisione del design con la skill apple-design ([#65](https://github.com/1r0n51uv/ron1n/pull/65))

## 2026-10-27

- SETUP-013: bootstrap a scelta ([#63](https://github.com/1r0n51uv/ron1n/pull/63))

## 2026-10-24

- SETUP-012: repo e stack senza sudo ([#61](https://github.com/1r0n51uv/ron1n/pull/61))
- IOSB-003: icona dell'app nella source di SideStore ([#59](https://github.com/1r0n51uv/ron1n/pull/59))
- Source di SideStore e build automatica dell'app iOS (IOSB-003, IOSB-004, SETUP-011) ([#57](https://github.com/1r0n51uv/ron1n/pull/57))

## 2026-10-23

- Cloudflare da script: tunnel, DNS e Access (SETUP-010) ([#53](https://github.com/1r0n51uv/ron1n/pull/53))
- Tailscale solo per l'SSH: via lo stack dns (SETUP-009) ([#52](https://github.com/1r0n51uv/ron1n/pull/52))
- README: l'app iOS nella tabella dei progetti ([#51](https://github.com/1r0n51uv/ron1n/pull/51))
- Tunnel in HTTP/2 invece di QUIC (SETUP-008) ([#50](https://github.com/1r0n51uv/ron1n/pull/50))
- SETUP-008: siti su \*.ron1n.space con Cloudflare Tunnel e Access ([#49](https://github.com/1r0n51uv/ron1n/pull/49))
- Spec SETUP-008/009: Cloudflare Tunnel e Access al posto di Tailscale ([#47](https://github.com/1r0n51uv/ron1n/pull/47))
- Spec SETUP-008: certificati Let's Encrypt per \*.home.ron1n.space ([#44](https://github.com/1r0n51uv/ron1n/pull/44))
- ios-builder: home di passwd in /work/home, così l'SDK resta sull'host ([#43](https://github.com/1r0n51uv/ron1n/pull/43))
- server-setup: spostamento di Docker su /srv senza rsync ([#42](https://github.com/1r0n51uv/ron1n/pull/42))
- Bootstrap: dati di Docker e containerd su /srv (SETUP-007) ([#41](https://github.com/1r0n51uv/ron1n/pull/41))
- Spec SETUP-007: dati di Docker su /srv ([#39](https://github.com/1r0n51uv/ron1n/pull/39))
- Builder iOS con xtool e pagina ios.ron1n.home (IOSB-001, IOSB-002) ([#38](https://github.com/1r0n51uv/ron1n/pull/38))
- Spec Build iOS: builder xtool e pagina di download (IOSB-001, IOSB-002) ([#35](https://github.com/1r0n51uv/ron1n/pull/35))
- infra: tolto lo stack webtop ([#34](https://github.com/1r0n51uv/ron1n/pull/34))
- ca.ron1n.home anche in HTTPS per Safari (SETUP-006) ([#32](https://github.com/1r0n51uv/ron1n/pull/32))
- DNS interno e certificato di Caddy per i client (SETUP-005, SETUP-006) ([#30](https://github.com/1r0n51uv/ron1n/pull/30))
- Bootstrap chiede i .env, cleanup senza Docker (SETUP-003, SETUP-004) ([#27](https://github.com/1r0n51uv/ron1n/pull/27))
- ron1nos: volume per il catalogo delle immagini degli esercizi ([#26](https://github.com/1r0n51uv/ron1n/pull/26))
- ron1nos: variabili per login e modulo Documenti ([#25](https://github.com/1r0n51uv/ron1n/pull/25))
- Bootstrap e cleanup del server (SETUP-001, SETUP-002) ([#24](https://github.com/1r0n51uv/ron1n/pull/24))

## 2026-10-22

- infra.sh: un solo script per avviare e spegnere tutti gli stack ([#21](https://github.com/1r0n51uv/ron1n/pull/21))
- Specifica INFRA: un solo script per accendere e spegnere l'infra ([#16](https://github.com/1r0n51uv/ron1n/pull/16))
- Pulizia: tolti backup, migrazione da EC2 e stati vecchi dalla documentazione ([#15](https://github.com/1r0n51uv/ron1n/pull/15))
- infra: variabili YAZIO nel .env.example di ron1nos ([#13](https://github.com/1r0n51uv/ron1n/pull/13))
- infra: tolti i dump notturni di Postgres ([#12](https://github.com/1r0n51uv/ron1n/pull/12))
- infra: stack postgres condiviso dalle app, database ron1nos ([#11](https://github.com/1r0n51uv/ron1n/pull/11))

## 2026-10-21

- Stack infra/ron1nos per la dashboard sul server ([#10](https://github.com/1r0n51uv/ron1n/pull/10))
- infra: stack webtop, desktop Linux nel browser ([#9](https://github.com/1r0n51uv/ron1n/pull/9))
- Regole di qualità, CI del hub e template app con lint, Prettier e test ([#7](https://github.com/1r0n51uv/ron1n/pull/7))
- infra/torrent: credenziali della Web UI da .env (admin/admin) ([#5](https://github.com/1r0n51uv/ron1n/pull/5))
- infra: stack glances per le risorse del server ([#3](https://github.com/1r0n51uv/ron1n/pull/3))
- infra: stack torrent con qBittorrent ([#2](https://github.com/1r0n51uv/ron1n/pull/2))
- Flusso di sviluppo: specifiche, issue, PR con CI, deploy su GHCR ([#1](https://github.com/1r0n51uv/ron1n/pull/1))

## 2026-10-20

- README: collega il repo ron1nOS
- Scheletro hub ron1n: README progetti, CLAUDE.md, infra home server
