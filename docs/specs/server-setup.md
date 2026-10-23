# Setup del server

Prefisso ID: `SETUP` · Label: `mod:server-setup`

Un solo comando porta il mini PC da Debian 13 appena installato (solo
`curl`) allo stack di [`infra/`](../../infra/) acceso e raggiungibile dalla
tailnet. L'avvio e lo spegnimento degli stack, dopo, sono di
[`infra.sh`](infra.md). Niente backup, per scelta.

## Requisiti

### SETUP-001 · Bootstrap del server con un comando

Stato: fatto (#24)

`curl -fsSL https://raw.githubusercontent.com/1r0n51uv/ron1n/main/scripts/bootstrap.sh | sh`,
da root, prepara il sistema e avvia tutto.

Accettazione:

- [x] Si ferma subito se non è Debian 13 (trixie) amd64 o non gira da root.
- [x] Installa i pacchetti base e gli aggiornamenti di sicurezza
      automatici.
- [x] Installa Docker Engine e Compose dal repo ufficiale, con i log dei
      container a rotazione.
- [x] Mette l'utente amministratore (il primo con UID ≥ 1000, o
      `RON1N_USER`) nei gruppi `sudo` e `docker`.
- [x] Installa Tailscale e unisce il server alla tailnet come `ron1n`
      (`TS_AUTHKEY` facoltativa, altrimenti mostra il link).
- [x] SSH: niente login di root; niente password se l'utente ha già una
      chiave.
- [x] Firewall: dalla LAN e da internet passano solo SSH e la porta
      BitTorrent, anche per le porte pubblicate da Docker; dalla tailnet
      tutto.
- [x] Clona il repo in `/opt/ron1n` (o lo aggiorna con fast-forward) e
      avvia gli stack con `./infra.sh up`.
- [x] Alla fine stampa l'IP della tailnet, la riga per `/etc/hosts` dei
      client, dove trovare il certificato radice di Caddy e le credenziali
      generate.
- [x] Si può rilanciare: rifà solo ciò che manca, non tocca `.env` né dati.

### SETUP-002 · Cleanup: l'opposto del bootstrap

Stato: fatto (#24)

`sudo /opt/ron1n/scripts/cleanup.sh` spegne gli stack e toglie dal server
quello che il bootstrap ha messo, chiedendo cosa eliminare.

Accettazione:

- [x] Chiede una voce alla volta, con no come risposta di default: stack
      (container, reti, `.env`), volumi, immagini, cartella dei download,
      firewall, regole SSH di ron1n, Tailscale, copia del repo sul server
      (SETUP-004).
- [x] Prima di cominciare mostra il riepilogo e vuole `cancella` scritto
      per esteso; con qualsiasi altra risposta non tocca niente.
- [x] Senza terminale le voci si scelgono con le opzioni (`--stacks`,
      `--all`…) e `--yes` salta la conferma.
- [x] Gli stack si spengono in ordine, come `./infra.sh down`, prima di
      cancellarne i dati.
- [x] Tailscale si toglie per ultimo; se la sessione SSH passa dalla
      tailnet, la rimozione finisce anche quando la connessione cade.
- [x] Non tocca mai il repo su GitHub, i pacchetti di base, gli
      aggiornamenti automatici e il gruppo `sudo` dell'utente.

### SETUP-003 · Il bootstrap chiede i `.env`

Stato: in corso

Prima del primo avvio il bootstrap chiede sul terminale i valori dei `.env`
degli stack, così parte tutto già configurato e non con valori di prova.

Accettazione:

- [x] Per ogni stack senza `.env` chiede ogni voce di `.env.example`,
      con il suo commento come spiegazione e il valore di esempio come
      default; il fuso orario una volta sola.
- [x] Password senza eco e scritte due volte; con invio una casuale. Le
      password di Postgres solo con caratteri validi in un URL.
- [x] Non chiede `PUID`/`PGID` (l'utente amministratore) né i valori che
      un altro stack ha già: credenziali di qBittorrent e `DATABASE_URL`
      di ron1nOS si riprendono da torrent e postgres.
- [x] ron1nOS: password della dashboard (almeno 12 caratteri) trasformata
      nell'hash scrypt di `AUTH_PASSWORD_HASH`; con il login, chiave del
      modulo Documenti generata; account YAZIO facoltativo, con la chiave
      dei token generata.
- [x] Valori con `$`, spazi o simili tra apici singoli, letti alla lettera
      da Compose. `.env` con permessi `600`, dell'amministratore.
- [x] Un `.env` che c'è già non si tocca; senza terminale li crea
      `./infra.sh up` con password casuali, come prima.
- [x] Alla fine stampa gli indirizzi `https://` dei servizi, il percorso
      di ogni `.env` e il promemoria di salvare `DOCUMENTS_KEY`.

### SETUP-004 · Cleanup senza Docker, volumi e immagini a parte

Stato: in corso

Accettazione:

- [x] Il cleanup non disinstalla più Docker Engine né toglie il gruppo
      `docker`: niente più voce `--docker`.
- [x] Volumi (`--volumes`) e immagini (`--images`) sono voci a sé,
      separate dagli stack (container, reti, `.env`, certificato di
      Caddy). Per toglierli spegne gli stack, ma lascia i `.env`.
- [x] Se si cancellano i `.env` ma non i volumi, il riepilogo avverte che
      Postgres tiene le password vecchie.

### SETUP-005 · Nomi `*.ron1n.home` su tutti i client

Stato: fatto (#30)

Telefono, tablet e computer della tailnet aprono i siti `*.ron1n.home`
senza toccare il file hosts, che su iOS non si può modificare.

Accettazione:

- [x] Lo stack `dns` (CoreDNS) risponde a ogni nome `*.ron1n.home`, e a
      `ron1n.home`, con l'IP Tailscale del server. Altri tipi (IPv6,
      HTTPS…) hanno una risposta vuota; le altre zone non le risolve.
- [x] Risponde solo alla tailnet: dalla LAN e da internet la porta 53 è
      chiusa dal firewall, come le altre porte dei container.
- [x] L'IP sta in `TS_IP` di `infra/dns/.env`: lo scrivono il bootstrap e
      `./infra.sh up` da `tailscale ip -4`. Senza Tailscale niente `.env`
      e lo stack non parte.
- [x] Il bootstrap, alla fine, spiega come attivare lo split DNS nella
      console Tailscale (nameserver = IP del server, solo `ron1n.home`) al
      posto della riga per il file hosts.
- [x] `docs/server-setup.md` ha i passi per iPhone, Mac e PC.

### SETUP-006 · Certificato di Caddy scaricabile dai client

Stato: fatto (#32)

Il certificato radice di Caddy si installa da un client senza `scp`,
anche da iPhone.

Accettazione:

- [x] `http://ca.ron1n.home` (in HTTP, solo tailnet) scarica il
      certificato radice di Caddy con il tipo
      `application/x-x509-ca-cert`, così Safari su iOS propone di
      installarlo come profilo.
- [x] Risponde anche in `https://ca.ron1n.home`, senza redirect da HTTP:
      Safari passa da solo a https, e lì basta accettare l'avviso del
      certificato non ancora attendibile.
- [x] Qualsiasi percorso dà il certificato: la chiave privata della CA non
      è mai raggiungibile.
- [x] `docs/server-setup.md` spiega come installarlo e renderlo
      attendibile su iPhone, macOS e Windows.

### SETUP-007 · Dati di Docker sul disco grande

Stato: proposto

Immagini, container, volumi e cache di build stanno su `/srv`, la
partizione grande, non su `/var`, che sul mini PC è di 12 GB e si riempie
con un paio di immagini pesanti (come il builder iOS).

Accettazione:

- [ ] Se `/srv` è un filesystem diverso da quello di `/var`, il bootstrap,
      prima di installare Docker, crea `/srv/docker` e `/srv/containerd`
      e li monta in bind su `/var/lib/docker` e `/var/lib/containerd`
      con due righe in `/etc/fstab` (dopo il mount di `/srv`). La
      configurazione di Docker e di containerd non cambia: con Docker 29
      le immagini stanno nello snapshotter di containerd, e `data-root`
      da solo non le sposterebbe.
- [ ] Se Docker ha già dati in `/var/lib/docker` o `/var/lib/containerd`
      non li sposta: lo dice e rimanda alla procedura manuale.
- [ ] Si può rilanciare: le righe in `/etc/fstab` non si duplicano.
- [ ] `docs/server-setup.md` ha la procedura per spostare a mano i dati
      di un server già installato, con il modo per tornare indietro.
- [ ] Il cleanup lascia i bind mount, come lascia Docker Engine.
