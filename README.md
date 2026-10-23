# ron1n

Brand personale di sviluppo software. Questo repo è l'hub: raccoglie i
progetti, l'identità visiva e la configurazione dell'home server su cui
girano. Ogni app vive nel suo repo.

## Progetti

| Progetto    | Cosa è                                                                                    | Repo                                                            | Stato                                     |
| ----------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------- |
| ron1nOS     | Dashboard dell'homelab: pasti, allenamenti, peso, casa, server, container, download, note | [1r0n51uv/ron1nOS](https://github.com/1r0n51uv/ron1nOS)         | Download, Server e Nutrizione collegati   |
| ron1nOS iOS | Versione iOS della dashboard                                                              | [1r0n51uv/ron1nos-ios](https://github.com/1r0n51uv/ron1nos-ios) | app di prova sul telefono, via Cloudflare |
| 1r0-pkm     | App iOS/Watch per palestra e dieta, API Fastify + Postgres                                | [1r0n51uv/1r0-pkm](https://github.com/1r0n51uv/1r0-pkm)         | deprecata, sola lettura                   |

## Identità

Liquid glass su nero, un solo accento rosso `#FF2A2A`. Font: Chakra Petch,
IBM Plex Sans, JetBrains Mono, Shippori Mincho. Logo: sigillo Hanko · Fasce.
Il design system ron1nOS (namespace `Ron1n`, 17 componenti React, token) è
la fonte di verità per tutte le interfacce.

## Come si sviluppa

Ogni app segue lo stesso flusso: specifica, issue con label, PR con CI,
immagine su GHCR, aggiornamento automatico sul server. Dettagli in
[`docs/flusso-sviluppo.md`](docs/flusso-sviluppo.md), template per un nuovo
repo in [`templates/app/`](templates/app/).

## Home server

Mini PC Ryzen 5 5300U, 16 GB RAM, Debian + Docker Compose. Configurazione
in [`infra/`](infra/), primo setup in [`docs/server-setup.md`](docs/server-setup.md).

Setup completo su Debian 13 appena installato: da root (`su -`) scarica ed
esegue [`scripts/bootstrap.sh`](scripts/bootstrap.sh), che chiede i valori
dei `.env` e alla fine stampa indirizzi e posizione dei `.env`.

```sh
curl -fsSL https://raw.githubusercontent.com/1r0n51uv/ron1n/main/scripts/bootstrap.sh | sh
```

Per tornare indietro: `sudo /opt/ron1n/scripts/cleanup.sh`.
