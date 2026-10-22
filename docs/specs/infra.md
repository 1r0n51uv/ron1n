# Infra

Prefisso ID: `INFRA` · Label: `mod:infra`

Gli stack Docker Compose di [`infra/`](../../infra/) si accendono e si
spengono tutti insieme con un solo script, `infra.sh` nella radice del
repo, anche la prima volta su un server appena installato. Non installa Docker né configura il
sistema: quello resta al primo setup del server
([`server-setup.md`](../server-setup.md)).

## Requisiti

### INFRA-001 · Avviare tutti gli stack con un comando

Stato: fatto (#21)

Dalla radice del repo (sul server `/opt/ron1n`) `./infra.sh up` accende
tutti gli stack di `infra/` nell'ordine giusto.

Accettazione:

- [ ] Senza argomenti avvia ogni stack con un `compose.yaml` in `infra/`,
      tranne le cartelle che iniziano con `_` (i template).
- [ ] L'ordine rispetta le dipendenze: Postgres per primo e sano prima di
      ron1nOS, Caddy per ultimo. Uno stack nuovo, non ancora nell'elenco,
      parte dopo gli altri senza modificare lo script.
- [ ] Con uno o più nomi (`./infra.sh up torrent ron1nos`) avvia solo quegli
      stack; un nome sconosciuto è un errore che elenca gli stack validi.
- [ ] Si può rilanciare: gli stack già accesi restano accesi, quelli con il
      compose cambiato vengono ricreati.
- [ ] Se Docker manca o non risponde si ferma subito con un messaggio che
      dice cosa fare; se uno stack non parte si ferma e indica quale.
- [ ] Alla fine mostra lo stato dei container avviati.
- [ ] Funziona con Docker 29 (Watchtower compreso).

### INFRA-002 · Primo avvio senza passaggi a mano

Stato: fatto (#21)

Su un server dove gli stack non sono mai partiti, `./infra.sh up` prepara
da solo quello che serve, senza toccare ciò che esiste già.

Accettazione:

- [ ] Crea le reti Docker esterne `proxy` e `db` se mancano.
- [ ] Per ogni stack con `.env.example` e senza `.env` crea il `.env`
      (permessi 600) con password casuali al posto di quelle d'esempio.
- [ ] I valori condivisi fra stack sono coerenti: la password del database
      di ron1nOS in Postgres è quella di `DATABASE_URL`, le credenziali di
      qBittorrent sono le stesse in torrent e ron1nos.
- [ ] `PUID`/`PGID` sono quelli dell'utente che lancia lo script (con
      `sudo`, quelli dell'utente che ha chiamato sudo).
- [ ] Crea la cartella dei download (`DOWNLOADS_DIR`) se manca.
- [ ] Un `.env` che esiste già non viene mai modificato. Uno stack nuovo con
      `.env.example` ma senza regole note non parte finché il `.env` non
      c'è: lo script lo dice e prosegue con gli altri.
- [ ] Dopo il primo avvio stampa dove sono le credenziali generate.

### INFRA-003 · Spegnere tutti gli stack con un comando

Stato: fatto (#21)

`./infra.sh down` spegne tutti gli stack, nell'ordine inverso all'avvio.

Accettazione:

- [ ] Senza argomenti spegne ogni stack di `infra/` (stessa selezione di
      INFRA-001), con nomi spegne solo quelli.
- [ ] Ordine inverso: prima Caddy, così niente è più raggiungibile, per
      ultimo Postgres, così le app chiudono le connessioni prima.
- [ ] Rimuove i container ma conserva volumi, `.env` e reti: dopo
      `./infra.sh up` tutto torna com'era, dati compresi.
- [ ] Uno stack già spento non è un errore.

### INFRA-004 · Vedere lo stato degli stack

Stato: fatto (#21)

`./infra.sh status` mostra, stack per stack, i container e il loro stato.
`./infra.sh` senza comando o con un comando sconosciuto spiega l'uso.

Accettazione:

- [ ] Per ogni stack elenca i container con stato e salute, o dice che è
      spento.
- [ ] Non cambia niente: non crea reti, `.env` né container.

## Note

- Niente backup, per scelta del 2026-10-22: lo spegnimento non salva nulla.
- Lo script di primo setup del server (`scripts/bootstrap.sh`, in prova)
  potrà chiamare `infra.sh up` invece di avviare gli stack da sé.
- Watchtower 1.7.1 parla con l'API Docker 1.25, che Docker 29 rifiuta:
  il suo compose fissa `DOCKER_API_VERSION=1.44`.
