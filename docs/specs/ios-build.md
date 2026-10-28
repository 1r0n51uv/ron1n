# Build iOS

Prefisso ID: `IOSB` · Label: `mod:ios-build`

Le app iOS di ron1n (per prima ron1nOS iOS) si compilano sul server di
casa, che è Linux: niente Mac, né nostro né in cloud. Lo fa
[xtool](https://github.com/xtool-org/xtool), che compila un pacchetto
SwiftPM in un'app iOS con l'SDK estratto da `Xcode.xip`. L'IPA esce non
firmata e la firma SideStore sul telefono con l'Apple ID del proprietario
(piano gratuito, rifirma ogni 7 giorni), come per 1r0-pkm: sul server non
ci sono credenziali Apple.

La licenza di Xcode ne ammette l'uso solo su hardware Apple: estrarne
l'SDK su Linux è una scelta del proprietario, fatta sapendolo.

## Requisiti

### IOSB-001 · Builder xtool sul server

Stato: fatto (#38)

Un comando sul server trasforma un commit del repo di un'app iOS in una
IPA non firmata.

Accettazione:

- [x] Lo stack `ios` ha un servizio `ios-builder`, costruito in locale da
      un Dockerfile con Swift e xtool a versioni fisse. Non parte con
      `./infra.sh up`: si lancia a mano con `docker compose run`.
- [x] Tutto quello che pesa (Xcode.xip, SDK, sorgenti, IPA) sta nella
      cartella `IOS_DIR` dell'host, `/srv/ron1n-ios` di default: fuori da
      `/var`, che ha poco spazio. I file sono dell'utente degli stack.
      Swift su Linux prende la home da `/etc/passwd`, non da `HOME`:
      nell'immagine l'utente 1000 ha la home in `/work/home`, e con un
      altro `PUID` il builder si ferma invece di perdere l'SDK.
- [x] `sdk` installa l'SDK iOS dall'unico `.xip` in `IOS_DIR`, una volta
      sola; dopo, il `.xip` si può cancellare.
- [x] `build [ref]` clona il repo `IOS_REPO` al ref dato (default `main`),
      compila in release e mette l'IPA in `IOS_DIR/builds` con nome
      `<app>-<commit>.ipa`, più una copia `<app>.ipa` sempre uguale
      all'ultima. Delle build vecchie restano le ultime 5.
- [x] Un repo privato si clona con `GITHUB_TOKEN` (token fine-grained,
      solo lettura dei contenuti), che non finisce nella configurazione
      git dei sorgenti clonati. Vuoto per un repo pubblico.
- [x] Senza SDK, senza `.xip` o con un errore di compilazione si ferma con
      un messaggio che dice cosa fare.

### IOSB-002 · Pagina di download su `ios.ron1n.space`

Stato: fatto (#38)

Dal telefono si scarica l'ultima IPA e la si apre con
SideStore.

Accettazione:

- [x] Lo stack `ios` ha un servizio `ios-builds` che pubblica
      `IOS_DIR/builds` in sola lettura, con l'elenco dei file; Caddy lo
      espone su `https://ios.ron1n.space`, dietro Cloudflare Access (SETUP-008).
- [x] `./infra.sh up` crea `infra/ios/.env` e la cartella delle build, e
      avvia la pagina anche prima della prima build.
- [x] Il bootstrap chiede `IOS_DIR`, `IOS_REPO` e `GITHUB_TOKEN`, il token
      senza mostrarlo. Il cleanup ha una voce che cancella `IOS_DIR` (SDK e
      build) e toglie l'immagine del builder insieme alle altre.
- [x] `infra/ios/README.md` spiega come scaricare `Xcode.xip`, installare
      l'SDK, fare una build e installarla con SideStore.

### IOSB-003 · Source di SideStore

Stato: in corso

Gli aggiornamenti arrivano in SideStore da una source, come per le app
dello store: si aggiunge una volta e a ogni nuova versione SideStore
propone Update. La source è un file statico che scrive il builder, senza
servizi in più.

Accettazione:

- [ ] `build` legge da `git rev-list --count HEAD` il numero di commit N
      e lo scrive nell'Info.plist dell'app (`infoPath` di `xtool.yml`)
      prima di compilare: `CFBundleVersion` = N e
      `CFBundleShortVersionString` = `major.minor.N`, con major e minor
      presi dal plist. A ogni commit la versione sale.
- [ ] Una build di `main` copia l'IPA in `IOS_DIR/builds/sidestore` e
      riscrive lì `source.json`, nel formato delle source di AltStore e
      SideStore: nome, bundle id (da `xtool.yml`), icona (`iconURL`,
      obbligatoria per SideStore, `icon.png` dall'immagine del builder),
      versione, build, data, dimensione e link assoluto all'IPA, che ha il
      commit nel nome. Ci
      sono anche i campi vecchi (`version`, `downloadURL`, `size`) per
      le versioni precedenti di SideStore. Una build di un altro ref non
      tocca la source.
- [ ] La source si aggiunge in SideStore con
      `https://ios.DOMINIO/sidestore/source.json`; l'indirizzo viene da
      `IOS_URL` in `infra/ios/.env`, che il bootstrap ricava da
      `DOMINIO`. La cartella è fuori da Cloudflare Access (SETUP-011).
- [ ] Anche in `sidestore` restano le ultime 5 IPA.
- [ ] Test senza xtool in `scripts/test-ios-build-sh.sh`, dentro
      `npm run check`: numero di versione, `source.json` con l'icona e pulizia.

### IOSB-004 · Build automatica a ogni commit

Stato: in corso

Dopo il merge di una PR dell'app non serve lanciare niente: il server se
ne accorge, compila e aggiorna la source.

Accettazione:

- [ ] Lo stack `ios` ha un servizio `ios-autobuild`, con l'immagine del
      builder, che parte con `./infra.sh up` e resta acceso con
      `ios-build segui`: ogni `IOS_INTERVALLO` secondi (300 di default)
      legge l'ultimo commit di main con `git ls-remote` e, se non è quello
      già pubblicato, lancia `build main`.
- [ ] Una build fallita non si ritenta finché non arriva un commit nuovo;
      senza SDK aspetta e lo scrive nel log, senza fermarsi.
- [ ] Una build alla volta: una build a mano e quella automatica si
      aspettano (lock su `IOS_DIR/.build.lock`).
- [ ] Niente da installare sull'host: è un container dello stack, quindi
      il cleanup lo toglie con gli stack e le immagini.

### IOSB-005 · Novità della versione

Stato: fatto (#67) · Richiesta del proprietario il 2026-10-28

In SideStore ogni versione mostra cosa cambia, non solo il commit.

Accettazione:

- [x] Le note della versione (`versions[].localizedDescription` di
      `source.json`) sono la sezione `## <versione>` del `CHANGELOG.md`
      dell'app, per esempio `## 0.1.62 · 2026-10-28`, senza le righe
      vuote.
- [x] Se il CHANGELOG manca o non ha la versione, le note sono i titoli
      dei commit dopo l'ultima versione pubblicata (al massimo 20), o il
      titolo dell'ultimo commit.
- [x] `json_str` protegge anche a capo e tab, così le note su più righe
      restano JSON valido.
- [x] Test in `scripts/test-ios-build-sh.sh`: note dal CHANGELOG, dai
      commit e nella source.
- [x] Immagine del builder `xtool-1.22.2-r4`: sul server serve
      `git pull --ff-only` e `./infra.sh up`.
