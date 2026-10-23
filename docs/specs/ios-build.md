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

### IOSB-002 · Pagina di download su `ios.home.ron1n.space`

Stato: fatto (#38)

Dal telefono, nella tailnet, si scarica l'ultima IPA e la si apre con
SideStore.

Accettazione:

- [x] Lo stack `ios` ha un servizio `ios-builds` che pubblica
      `IOS_DIR/builds` in sola lettura, con l'elenco dei file; Caddy lo
      espone su `https://ios.home.ron1n.space`, solo tailnet.
- [x] `./infra.sh up` crea `infra/ios/.env` e la cartella delle build, e
      avvia la pagina anche prima della prima build.
- [x] Il bootstrap chiede `IOS_DIR`, `IOS_REPO` e `GITHUB_TOKEN`, il token
      senza mostrarlo. Il cleanup ha una voce che cancella `IOS_DIR` (SDK e
      build) e toglie l'immagine del builder insieme alle altre.
- [x] `infra/ios/README.md` spiega come scaricare `Xcode.xip`, installare
      l'SDK, fare una build e installarla con SideStore.
