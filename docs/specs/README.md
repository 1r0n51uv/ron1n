# Specifiche del hub ron1n

Il hub non ha app sue: le specifiche qui descrivono il server di casa e
gli strumenti per gestirlo. Il flusso (specifica → issue → PR → deploy) è
in [`flusso-sviluppo.md`](../flusso-sviluppo.md).

## Moduli

| Modulo           | File                               | Prefisso ID | Label              |
| ---------------- | ---------------------------------- | ----------- | ------------------ |
| Infra            | [infra.md](infra.md)               | `INFRA`     | `mod:infra`        |
| Setup del server | [server-setup.md](server-setup.md) | `SETUP`     | `mod:server-setup` |
| Build iOS        | [ios-build.md](ios-build.md)       | `IOSB`      | `mod:ios-build`    |

## Stati dei requisiti

`proposto` → `pianificato (#issue)` → `in corso (#issue)` → `fatto (#PR)`,
oppure `rimosso`. Gli ID non si riusano.
