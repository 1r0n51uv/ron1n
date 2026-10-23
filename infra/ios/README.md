# ios

Le app iOS di ron1n si compilano qui, sul server, con
[xtool](https://github.com/xtool-org/xtool): niente Mac. L'IPA esce non
firmata e si installa sul telefono con SideStore, che la firma con il tuo
Apple ID. Specifica: [`docs/specs/ios-build.md`](../../docs/specs/ios-build.md).

| Servizio      | Cosa fa                                                                        |
| ------------- | ------------------------------------------------------------------------------ |
| `ios-builds`  | pagina `https://ios.home.ron1n.space` con le IPA, sempre accesa, solo tailnet  |
| `ios-builder` | Swift e xtool; si lancia a mano, non parte con `./infra.sh up` (profilo build) |

## Configurazione

In `.env`:

- `IOS_DIR`: cartella dell'host per Xcode.xip, SDK, sorgenti e IPA,
  `/srv/ron1n-ios` di default. Servono una decina di GB liberi: non in
  `/var`.
- `IOS_REPO`: il repo dell'app, `ron1nos-ios` di default.
- `GITHUB_TOKEN`: per un repo privato. Su GitHub, **Settings → Developer
  settings → Fine-grained tokens**, solo il repo dell'app, permesso
  **Contents: Read-only**. Vuoto per un repo pubblico.

`./infra.sh up` crea `.env` e le cartelle; dopo una modifica rilancia
`sudo ./infra.sh up ios`.

## SDK iOS, una volta sola

1. Da un browser qualsiasi, con il tuo Apple ID (basta quello gratuito),
   scarica **Xcode 27** da
   [developer.apple.com/download/all](https://developer.apple.com/download/all/?q=Xcode).
   Pesa diversi GB.
2. Copialo nella cartella `IOS_DIR` del server, per esempio
   `scp Xcode_27.xip <utente>@ron1n:/srv/ron1n-ios/`.
3. Installa l'SDK (qualche minuto; la prima volta costruisce anche
   l'immagine del builder):

   ```sh
   cd /opt/ron1n
   docker compose -f infra/ios/compose.yaml run --rm ios-builder sdk
   ```

4. Controlla che l'SDK sia sull'host, in `IOS_DIR/home/.swiftpm/swift-sdks`,
   poi il `.xip` si può cancellare.

La licenza di Xcode ne ammette l'uso solo su hardware Apple: estrarne
l'SDK su Linux è una zona grigia, scelta sapendolo.

## Build

```sh
docker compose -f infra/ios/compose.yaml run --rm ios-builder build        # main
docker compose -f infra/ios/compose.yaml run --rm ios-builder build v0.2   # un tag, branch o commit
```

L'IPA va in `IOS_DIR/builds` come `<app>-<commit>.ipa` e come `<app>.ipa`,
sempre l'ultima. Restano le ultime 5 build.

## Installazione sul telefono

Nella tailnet, da Safari: `https://ios.home.ron1n.space`, tocca l'IPA, poi
**Condividi → SideStore** (oppure in SideStore **+** e scegli il file da
**Download**). SideStore la firma e la installa; con l'Apple ID gratuito
la firma dura 7 giorni e SideStore la rinnova da solo.

## Aggiornare Swift o xtool

Le versioni sono fisse in [`builder/Dockerfile`](builder/Dockerfile) e
nel tag dell'immagine in `compose.yaml`: cambiale insieme, poi
`docker compose -f infra/ios/compose.yaml build ios-builder`. Una versione
nuova di xtool può chiedere una versione nuova di Xcode: in quel caso
rifai l'SDK (`xtool sdk remove` dentro il builder, poi `sdk`).
