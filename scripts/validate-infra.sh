#!/usr/bin/env bash
# Valida gli stack in infra/: `docker compose config` su ogni compose.yaml
# (con i valori di .env.example) e il Caddyfile. Non serve il demone Docker.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for compose in infra/*/compose.yaml; do
  dir=$(dirname "$compose")
  stack=$(basename "$dir")
  work="$tmp/$stack"
  cp -r "$dir" "$work"
  # Il template usa il segnaposto <app>, non valido come nome di progetto.
  sed -i 's/<app>/esempio/g' "$work/compose.yaml"
  # env_file: .env non è versionato: al suo posto .env.example, o un file vuoto.
  if [[ -f "$work/.env.example" ]]; then cp "$work/.env.example" "$work/.env"; else touch "$work/.env"; fi
  if docker compose --project-directory "$work" -f "$work/compose.yaml" config --quiet; then
    echo "ok   $compose"
  else
    echo "FAIL $compose"
    status=1
  fi
done

if command -v caddy >/dev/null; then
  caddy validate --adapter caddyfile --config infra/proxy/Caddyfile
  # Il Caddyfile segue il formato di `caddy fmt`.
  if ! caddy fmt infra/proxy/Caddyfile | diff -u infra/proxy/Caddyfile -; then
    echo "FAIL infra/proxy/Caddyfile: esegui caddy fmt --overwrite"
    status=1
  fi
else
  echo "skip infra/proxy/Caddyfile: caddy non installato"
fi

exit $status
