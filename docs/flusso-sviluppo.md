# Flusso di sviluppo

Vale per ogni app ron1n. Il template da copiare in un nuovo repo è in
[`templates/app/`](../templates/app/).

```
specifica ─▶ issue con label ─▶ PR + CI ─▶ merge ─▶ immagine GHCR ─▶ Watchtower sul mini PC
```

## 1. Specifica

Ogni cambiamento parte dalla specifica, nel repo dell'app:

- `docs/specs/README.md`: panoramica dell'app e indice dei moduli;
- `docs/specs/<modulo>.md`: un file per modulo, partendo da
  [`_modulo.md`](../templates/app/docs/specs/_modulo.md).

Ogni requisito ha un ID stabile `<PREFISSO>-<NNN>` (es. `PASTI-003`), dice
cosa fa l'app (non come), ha criteri di accettazione e uno stato:

| Stato              | Significato                         |
| ------------------ | ----------------------------------- |
| `proposto`         | scritto, non ancora pianificato     |
| `pianificato (#N)` | esiste la issue #N                  |
| `in corso (#N)`    | c'è una PR aperta per la issue #N   |
| `fatto (#PR)`      | mergiato con la PR indicata         |
| `rimosso`          | non più previsto; l'ID non si riusa |

La modifica alla specifica va in una PR a sé, con label `spec` e
`type:docs`, senza codice. Così la specifica resta l'elenco completo di cosa
fa l'app.

## 2. Issue

Dopo il merge della specifica, ogni requisito nuovo o cambiato diventa una
issue (una per requisito, o più se è grande):

- titolo `[PASTI-003] Registrare un pasto`;
- corpo con link alla specifica e criteri di accettazione copiati;
- label secondo lo schema sotto. Lo stato del requisito passa a
  `pianificato (#N)`.

Claude crea le issue su richiesta ("crea le issue da `pasti.md`").

### Label

Uguali in tutti i repo, definite in `.github/labels.yml` e applicate dalla
Action `labels.yml` a ogni modifica del file.

| Gruppo   | Label                                                               |
| -------- | ------------------------------------------------------------------- |
| Tipo     | `type:feature`, `type:bug`, `type:chore`, `type:docs`, `type:infra` |
| Modulo   | `mod:<nome>`, una per file di specifica                             |
| Priorità | `prio:alta`, `prio:media`, `prio:bassa`                             |
| Extra    | `spec`, `blocked`                                                   |

Le label `mod:*` si aggiungono a `labels.yml` insieme al file di specifica
del modulo.

## 3. PR e CI

- Un branch e una PR per issue, con `Closes #N` nel corpo
  ([template](../templates/app/.github/pull_request_template.md)).
- Nella stessa PR lo stato del requisito passa a `fatto`.
- `ci.yml` gira su ogni PR: install, controllo del formato, lint,
  typecheck, test unit, build, test e2e e build dell'immagine Docker senza
  push. Gli stessi passi, in ordine, sono `npm run check` in locale.
- Branch protection su `main`: PR obbligatoria, check `ci` verde, merge
  solo squash (un task = un commit).

### Qualità del codice

Regole uguali in tutte le app web/Node, con la configurazione pronta in
[`templates/app/`](../templates/app/). L'esempio di riferimento è ron1nOS.

| Strumento    | File                   | Regola                                                                                                                                                                  |
| ------------ | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prettier     | `.prettierrc.json`     | Lo stile non si discute: niente punto e virgola, apici singoli (doppi nello YAML), 110 colonne, classi Tailwind ordinate dal plugin. `npm run format` prima del commit. |
| ESLint       | `eslint.config.js`     | typescript-eslint, react-hooks (con le regole del React Compiler), react-refresh. Zero warning: `--max-warnings 0`.                                                     |
| TypeScript   | `tsconfig*.json`       | `npm run typecheck`, separato dalla build.                                                                                                                              |
| Vitest       | `vite.config.ts`       | Test unit e di componente in `*.test.ts(x)` accanto al file, con Testing Library.                                                                                       |
| Playwright   | `playwright.config.ts` | Test e2e in `e2e/` sulla build di produzione (`vite preview`), Chromium desktop.                                                                                        |
| EditorConfig | `.editorconfig`        | UTF-8, LF, 2 spazi.                                                                                                                                                     |

Ogni PR porta i suoi test: unit per la logica e i componenti, almeno uno
scenario e2e per ciò che l'utente vede. Un test non si disattiva né si salta
per far passare la CI: si corregge il codice o il test.

Gli script npm comuni sono in
[`package.scripts.json`](../templates/app/package.scripts.json); la CI li
chiama per nome, quindi un'app con uno stack diverso deve offrire gli stessi
comandi.

### CI del hub

Anche questo repo ha il suo `ci.yml` (`npm run check` in locale): formato
di Markdown, YAML e JSON con Prettier, lint del Markdown con markdownlint,
`docker compose config` su ogni stack di `infra/` (con i valori di
`.env.example`), `caddy validate` e `caddy fmt` sul Caddyfile, actionlint
sui workflow, compresi quelli del template.

## 4. Pubblicazione

`release.yml` gira al push su `main` e pubblica su
`ghcr.io/1r0n51uv/<app>` due tag:

- `main`: quello che segue il server;
- `sha-<commit>`: per tornare indietro.

Solo `linux/amd64` (il mini PC). Usa `GITHUB_TOKEN`, nessun segreto da
configurare. Le app sono stateless, per questo il tag mobile `main` è
accettato; database e servizi con dati restano a tag fisso.

## 5. Deploy sul mini PC

Ogni app ha uno stack `infra/<app>/compose.yaml` in questo repo, partendo da
[`infra/_app-template/`](../infra/_app-template/compose.yaml), con
l'etichetta `com.centurylinklabs.watchtower.enable: "true"`. Watchtower
([`infra/updates`](../infra/updates/compose.yaml)) controlla GHCR ogni
5 minuti e riavvia il container quando `main` cambia.

Se il pacchetto GHCR è privato, sul server:

```sh
echo <token-read:packages> | docker login ghcr.io -u 1r0n51uv --password-stdin
```

poi in [`infra/updates/compose.yaml`](../infra/updates/compose.yaml) attiva
la riga che monta `/root/.docker/config.json`, così Watchtower usa le stesse
credenziali.

**Rollback:** nel compose dell'app si fissa `image: ...:sha-<commit>`, poi
`docker compose up -d`. Si torna a `main` quando la correzione è mergiata.

Il runner self-hosted è un'evoluzione possibile, utile solo se servirà una
sequenza di deploy (migrazioni del DB prima del riavvio, smoke test).

## Nuovo repo app

1. Copia il contenuto di `templates/app/` nella radice del repo, compresi
   i file nascosti, e copia gli script e le dipendenze di
   `package.scripts.json` in `package.json` (poi cancellalo).
2. Compila `docs/specs/README.md` e il primo `docs/specs/<modulo>.md`.
3. Adatta `ci.yml` allo stack (il template è per Node) e scrivi il
   `Dockerfile`.
4. Su GitHub: Settings → Branches, regola per `main` con PR obbligatoria e
   check `ci`; Settings → General, solo "Allow squash merging".
5. Aggiungi l'app alla tabella del [README](../README.md) e il suo stack in
   `infra/`.
