# CLAUDE.md

Regole per le sessioni di Claude su questo repo. Il flusso completo è in
https://github.com/1r0n51uv/ron1n/blob/main/docs/flusso-sviluppo.md.

- Documentazione, commenti, issue e PR in italiano.
- Prima la specifica: ogni cambiamento di comportamento parte da una PR su
  `docs/specs/<modulo>.md`, senza codice, con label `spec` e `type:docs`.
- Ogni requisito ha un ID `<PREFISSO>-<NNN>` che non si riusa.
- Una issue per requisito, titolo `[ID] titolo`, con le label `type:*`,
  `mod:*` e `prio:*` di `.github/labels.yml`.
- Una PR per issue, con `Closes #N`; nella stessa PR aggiorna lo stato del
  requisito a `fatto (#PR)`.
- Ogni PR porta i suoi test: unit (Vitest, `*.test.ts(x)` accanto al file)
  e almeno uno scenario e2e (Playwright, `e2e/`) per ciò che l'utente vede.
- Lo stile lo decide Prettier (`npm run format`); ESLint con zero warning.
  Prima di consegnare `npm run check` deve essere pulito.
- La CI (`ci.yml`) deve essere verde prima del merge. Non disattivare né
  saltare test per farla passare.
- Il merge su `main` pubblica l'immagine su GHCR e il server si aggiorna da
  solo: `main` deve essere sempre deployabile.
