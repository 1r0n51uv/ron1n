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

Stato: superato da SETUP-009

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

Stato: superato da SETUP-008 (#49)

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

Stato: fatto (#41)

Immagini, container, volumi e cache di build stanno su `/srv`, la
partizione grande, non su `/var`, che sul mini PC è di 12 GB e si riempie
con un paio di immagini pesanti (come il builder iOS).

Accettazione:

- [x] Se `/srv` è un filesystem diverso da quello di `/var`, il bootstrap,
      prima di installare Docker, crea `/srv/docker` e `/srv/containerd`
      e li monta in bind su `/var/lib/docker` e `/var/lib/containerd`
      con due righe in `/etc/fstab` (dopo il mount di `/srv`). La
      configurazione di Docker e di containerd non cambia: con Docker 29
      le immagini stanno nello snapshotter di containerd, e `data-root`
      da solo non le sposterebbe.
- [x] Se Docker ha già dati in `/var/lib/docker` o `/var/lib/containerd`
      non li sposta: lo dice e rimanda alla procedura manuale.
- [x] Si può rilanciare: le righe in `/etc/fstab` non si duplicano.
- [x] `docs/server-setup.md` ha la procedura per spostare a mano i dati
      di un server già installato, con il modo per tornare indietro.
- [x] Il cleanup lascia i bind mount, come lascia Docker Engine.

### SETUP-008 · Accesso da fuori con Cloudflare Tunnel e Access

Stato: fatto (#49)

I siti del server si aprono da ogni client, dentro e fuori casa, senza VPN
né certificati da installare: li pubblica un Cloudflare Tunnel su
`ron1n.space` (registrato su Namecheap, DNS su Cloudflare) e li protegge
Cloudflare Access. Toglie di mezzo la CA di Caddy, che le app iOS
rifiutano (TLS -9802) anche quando Safari la accetta, e la VPN, che su
iPhone è in conflitto con quella di SideStore.

Accettazione:

- [x] Uno stack `tunnel` con `cloudflared` a versione fissa, in rete
      `proxy`, lancia il tunnel con `TUNNEL_TOKEN` in
      `infra/tunnel/.env` (il bootstrap lo chiede senza mostrarlo; senza,
      lo stack non parte). Connessione solo in uscita: il router non si
      tocca.
- [x] Il tunnel ha un solo hostname pubblico, `*.ron1n.space` →
      `http://caddy:80`, più il record DNS wildcard: è Caddy a smistare
      per nome, nel Caddyfile versionato. Un solo livello di sottodominio,
      perché il certificato gratuito di Cloudflare copre `*.ron1n.space` e
      non `*.home.ron1n.space`.
- [x] I nomi: `home.ron1n.space` per la dashboard, poi `status.`,
      `torrent.`, `glances.` e `ios.ron1n.space`. Il dominio sta in
      `DOMINIO` (default `ron1n.space`) in `infra/proxy/.env`, non scritto
      a mano nei file.
- [x] Caddy serve solo HTTP sulla rete `proxy`, niente certificati né
      porte pubblicate sull'host: HTTPS lo fa Cloudflare. Si fida di
      `X-Forwarded-*` dal tunnel (`trusted_proxies`), così i backend vedono
      `https` e l'IP vero del client. Un nome che non è di nessun servizio
      riceve un errore.
- [x] Cloudflare Access protegge `*.ron1n.space`: dal browser si entra con
      un codice via mail all'indirizzo del proprietario; l'app iOS con un
      service token (header `CF-Access-Client-Id` e
      `CF-Access-Client-Secret`). Nessun nome passa dal tunnel senza
      Access, Glances e qBittorrent compresi, che non hanno login.
- [x] Il tunnel si collega a Cloudflare in HTTP/2 su TCP
      (`--protocol http2`), non in QUIC: in QUIC le connessioni verso
      alcuni data center restavano appese e le richieste duravano fino a
      un minuto.
- [x] `docs/server-setup.md` spiega come creare tunnel, hostname
      wildcard, applicazione Access, policy e service token nella
      dashboard Cloudflare. Ricorda il limite di 100 MB per richiesta del
      piano gratuito (upload di documenti e file).
- [x] Spariscono `local_certs`, `ron1n.home` e la pagina `ca.ron1n.home`
      (SETUP-006); riferimenti, README e la pagina `ios` usano i nomi
      nuovi.

### SETUP-009 · Tailscale solo per l'SSH

Stato: fatto (#52)

Dopo SETUP-008 siti, API e app passano da Cloudflare Tunnel con Access, e
lo split DNS di `*.ron1n.home` non serve più. Tailscale resta, ma solo per
l'SSH: la porta 22 attraverso Cloudflare, da qualsiasi client, c'è solo
con Spectrum, che è a pagamento, e aprire la 22 sul router esporrebbe il
server (scelta del proprietario, 23/10).

Accettazione:

- [x] Lo stack `dns` (SETUP-005) sparisce, con `TS_IP` in `infra.sh`, nel
      bootstrap e nei test: i nomi li risolve il DNS pubblico di
      Cloudflare.
- [x] Il bootstrap installa ancora Tailscale con Tailscale SSH e lascia
      aperta la sua interfaccia nel firewall; il cleanup lo toglie come
      prima.
- [x] `docs/server-setup.md` spiega come spegnere lo stack `dns` su un
      server che lo ha e come togliere lo split DNS dalla console
      Tailscale.
- [x] `CLAUDE.md` dice che siti e API passano solo da Cloudflare Tunnel
      con Access, e che Tailscale resta solo per l'SSH.

### SETUP-010 · Cloudflare da script

Stato: fatto (#53)

Tunnel, DNS e Access di SETUP-008 si preparano con un comando, non a mano
nella dashboard: la prima volta li ha creati la CLI `cf`, e lo script
rifà gli stessi passi con l'API di Cloudflare, per un account nuovo o per
rimettere a posto quello di oggi.

Accettazione:

- [x] `scripts/cloudflare.sh` crea o aggiorna, cercandoli per nome: il
      tunnel `ron1n` gestito da Cloudflare con `*.DOMINIO` →
      `http://caddy:80` e 404 per il resto, il CNAME `*` verso il tunnel
      con proxy, la policy email "ron1n · <nome>", il service token
      `ron1nos-ios` (un anno) con la sua policy Service Auth e
      l'applicazione Access `ron1n` su `*.DOMINIO` con sessione di un
      mese. Rilanciato non crea doppioni.
- [x] Il dominio viene da `infra/proxy/.env`. Credenziali ed email in
      `~/.cf-home/.env` (600): `CLOUDFLARE_API_TOKEN`,
      `CLOUDFLARE_ACCOUNT_ID`, `ACCESS_EMAIL`. Il token ha solo i permessi
      che servono: Cloudflare Tunnel, Access: Apps and Policies, Access:
      Service Tokens in modifica sull'account, DNS in modifica sulla zona.
- [x] Scrive token del tunnel e credenziali del service token in
      `~/.cf-home` con permessi 600 e non li stampa mai. Il secret si
      legge solo alla creazione: `--ruota` ne fa uno nuovo e il vecchio
      smette di valere.
- [x] `--dry-run` legge e dice cosa farebbe, senza scrivere niente. Se
      Cloudflare risponde con un errore, esce e ne mostra il messaggio.
- [x] Test con un curl finto in `scripts/test-cloudflare-sh.sh`, dentro
      `npm run check`. `jq` diventa un pacchetto di base del bootstrap,
      che il cleanup lascia come curl e git.
- [x] Tutto sul piano gratuito di Cloudflare.

### SETUP-011 · Eccezione di Access per SideStore

Stato: in corso

SideStore scarica la source e le IPA da solo e non sa fare il login di
Cloudflare Access (né mandare il service token). Una sola cartella di
`ios.DOMINIO` resta quindi aperta: quella che contiene la source e le IPA
(IOSB-003). Il resto di `*.DOMINIO`, comprese la pagina di `ios` e le
build di prova, resta dietro Access.

Accettazione:

- [ ] `scripts/cloudflare.sh` crea o aggiorna la policy riusabile
      "ron1n · pubblico" (Bypass, tutti) e l'applicazione Access
      "ron1n · SideStore" sul percorso `ios.DOMINIO/sidestore`, che vale
      prima di quella su `*.DOMINIO`. Rilanciato non crea doppioni.
- [ ] Bastano i permessi del token di SETUP-010. Tutto sul piano gratuito.
- [ ] Nella cartella pubblica ci sono solo le IPA di main e la source: il
      service token di Access e il token di ron1nOS non sono nell'IPA,
      l'utente li incolla nell'app.
- [ ] Test con il curl finto di `scripts/test-cloudflare-sh.sh`.

### SETUP-012 · Repo e stack senza sudo

Stato: in corso

`/opt/ron1n` era di root: ogni `git pull` e ogni `./infra.sh` chiedeva
sudo, quindi l'intervento del proprietario. Il repo diventa
dell'amministratore, già nel gruppo `docker` (SETUP-001): aggiornare il
repo e accendere o spegnere gli stack non richiede sudo, e Claude dal
server lo fa da solo. Sudo resta per il sistema (apt, systemctl,
Tailscale, fstab).

Accettazione:

- [ ] Il bootstrap clona `/opt/ron1n` come amministratore; un repo già
      clonato da root passa all'amministratore (`chown -R`) e git gira
      come lui.
- [ ] `./infra.sh up|down|status` funziona senza sudo dal proprietario del
      repo; con sudo funziona come prima.
- [ ] `docs/server-setup.md` e i README degli stack non chiedono più sudo
      per git e `infra.sh`, e spiegano il passaggio per un server già
      installato.
- [ ] Il cleanup non cambia: toglie il repo come prima, di chiunque sia.
