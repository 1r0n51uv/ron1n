#!/bin/sh
# Test di cloudflare.sh (SETUP-010) con un curl finto: risponde come l'API
# di Cloudflare tenendo tunnel, record, policy, token e applicazioni in
# file JSON, e registra ogni chiamata. Non va in rete.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

ok() { echo "ok   $*"; }
ko() {
  echo "FAIL $*"
  fails=$((fails + 1))
}
check() {
  desc=$1
  shift
  if "$@"; then ok "$desc"; else ko "$desc"; fi
}

command -v jq >/dev/null || {
  echo "manca jq"
  exit 1
}

bin=$tmp/bin
mkdir -p "$bin"
cat >"$bin/curl" <<'FAKE'
#!/bin/sh
m=GET
data=
url=
while [ $# -gt 0 ]; do
  case $1 in
    -X) m=$2; shift ;;
    -H) shift ;;
    --data) data=$2; shift ;;
    -*) ;;
    *) url=$1 ;;
  esac
  shift
done
path=${url#"$CF_API"}
echo "$m $path" >>"$LOG"
[ -f "$STATE/errore" ] && {
  echo '{"success":false,"errors":[{"message":"token senza permessi"}]}'
  exit 0
}
ok() { jq -nc --argjson r "$1" '{success: true, result: $r}'; }
lista() {
  f=$STATE/$1.json
  [ -f "$f" ] || echo '[]' >"$f"
  ok "$(cat "$f")"
}
aggiungi() {
  f=$STATE/$1.json
  [ -f "$f" ] || echo '[]' >"$f"
  id="$1-$(jq length "$f")"
  jq --arg id "$id" --argjson d "$data" '. + [$d + {id: $id}]' "$f" >"$f.new" && mv "$f.new" "$f"
  ok "$(printf '%s' "$data" | jq --arg id "$id" --arg extra "${2:-}" '. + {id: $id} + (if $extra == "" then {} else ($extra | fromjson) end)')"
}
case "$m $path" in
  "GET "*/cfd_tunnel\?*) lista tunnel ;;
  "POST "*/cfd_tunnel) aggiungi tunnel ;;
  "PUT "*/configurations) ok '{}' ;;
  "GET "*/token) ok '"TOKEN-DEL-TUNNEL"' ;;
  "GET /zones?name=ron1n.space") ok '[{"id":"z1"}]' ;;
  "GET /zones?"*) ok '[]' ;;
  "GET "*/dns_records\?*) lista dns ;;
  "POST "*/dns_records) aggiungi dns ;;
  "PUT "*/dns_records/*) ok '{}' ;;
  "GET "*/access/policies) lista policy ;;
  "POST "*/access/policies) aggiungi policy ;;
  "PUT "*/access/policies/*) ok '{}' ;;
  "GET "*/access/service_tokens) lista token ;;
  "POST "*/access/service_tokens) aggiungi token '{"client_id":"id.access","client_secret":"SEGRETO-1"}' ;;
  "POST "*/rotate) ok '{"id":"token-0","client_id":"id.access","client_secret":"SEGRETO-2"}' ;;
  "GET "*/access/apps) lista app ;;
  "POST "*/access/apps) aggiungi app ;;
  "PUT "*/access/apps/*) ok '{}' ;;
  *) echo '{"success":false,"errors":[{"message":"percorso sconosciuto"}]}' ;;
esac
FAKE
chmod +x "$bin/curl"

export PATH="$bin:$PATH" CF_API=https://api.finta LOG="$tmp/log" STATE="$tmp/state"
export HOME="$tmp/home" CF_HOME="$tmp/home/.cf-home"
mkdir -p "$STATE" "$CF_HOME"
cat >"$CF_HOME/.env" <<'EOF'
CLOUDFLARE_API_TOKEN=finto
CLOUDFLARE_ACCOUNT_ID=acc
ACCESS_EMAIL=sev.amm.dev@gmail.com
EOF

run() {
  : >"$LOG"
  "$ROOT/scripts/cloudflare.sh" "$@" >"$tmp/out" 2>&1
}
calls() { grep -c "^$1 " "$LOG" || true; }

# Prova: legge ma non scrive niente.
run --dry-run
check "dry-run: termina senza errori" true
check "dry-run: nessuna scrittura" test "$(calls POST)$(calls PUT)" = 00
check "dry-run: dice cosa farebbe" grep -q "farei: POST /accounts/acc/cfd_tunnel" "$tmp/out"
check "dry-run: nessun file" test ! -f "$CF_HOME/tunnel-token"

# Primo giro: crea tutto.
run
check "primo giro: termina senza errori" true
check "primo giro: un tunnel" test "$(jq length "$STATE/tunnel.json")" = 1
check "primo giro: instradamento a Caddy" grep -q "PUT /accounts/acc/cfd_tunnel/tunnel-0/configurations" "$LOG"
check "primo giro: CNAME wildcard con proxy" \
  test "$(jq -r '.[0] | "\(.name) \(.content) \(.proxied)"' "$STATE/dns.json")" = "* tunnel-0.cfargotunnel.com true"
check "primo giro: policy email" test "$(jq -r '.[0].name' "$STATE/policy.json")" = "ron1n · sev"
check "primo giro: policy del token" test "$(jq -r '.[1].include[0].service_token.token_id' "$STATE/policy.json")" = token-0
check "primo giro: applicazione su *.ron1n.space" test "$(jq -r '.[0].domain' "$STATE/app.json")" = "*.ron1n.space"
check "primo giro: sessione di un mese" test "$(jq -r '.[0].session_duration' "$STATE/app.json")" = 730h
check "primo giro: le due policy nell'applicazione" \
  test "$(jq -c '[.[0].policies[].id]' "$STATE/app.json")" = '["policy-0","policy-1"]'
check "primo giro: eccezione solo sulla cartella di SideStore" \
  test "$(jq -r '.[1].domain' "$STATE/app.json")" = "ios.ron1n.space/sidestore"
check "primo giro: policy bypass per tutti" \
  test "$(jq -c '.[2] | [.decision, .include]' "$STATE/policy.json")" = '["bypass",[{"everyone":{}}]]'
check "primo giro: l'eccezione usa la policy pubblica" \
  test "$(jq -c '[.[1].policies[].id]' "$STATE/app.json")" = '["policy-2"]'
check "primo giro: token del tunnel salvato" test "$(cat "$CF_HOME/tunnel-token")" = TOKEN-DEL-TUNNEL
check "primo giro: credenziali dell'app salvate" test "$(jq -r .client_secret "$CF_HOME/ron1nos-ios.json")" = SEGRETO-1
for f in tunnel-token ron1nos-ios.json; do
  check "primo giro: $f con permessi 600" test "$(stat -c %a "$CF_HOME/$f")" = 600
done
check "primo giro: niente segreti a schermo" sh -c "! grep -q -e SEGRETO -e TOKEN-DEL-TUNNEL '$tmp/out'"

# Rilancio: trova tutto per nome, non crea doppioni.
run
check "rilancio: nessuna creazione" test "$(calls POST)" = 0
check "rilancio: un solo tunnel" test "$(jq length "$STATE/tunnel.json")" = 1
check "rilancio: tre sole policy" test "$(jq length "$STATE/policy.json")" = 3
check "rilancio: due sole applicazioni" test "$(jq length "$STATE/app.json")" = 2
check "rilancio: secret invariato" test "$(jq -r .client_secret "$CF_HOME/ron1nos-ios.json")" = SEGRETO-1

# Rotazione del secret.
run --ruota
check "ruota: chiama rotate" grep -q "POST /accounts/acc/access/service_tokens/token-0/rotate" "$LOG"
check "ruota: secret nuovo nel file" test "$(jq -r .client_secret "$CF_HOME/ron1nos-ios.json")" = SEGRETO-2

# Token esistente ma file perso: lo dice.
rm "$CF_HOME/ron1nos-ios.json"
run
check "file perso: suggerisce --ruota" grep -q "rilancia con --ruota" "$tmp/out"

# Errori.
touch "$STATE/errore"
if run; then ko "errore dell'API: esce"; else ok "errore dell'API: esce"; fi
check "errore dell'API: mostra il messaggio" grep -q "token senza permessi" "$tmp/out"
rm "$STATE/errore" "$CF_HOME/.env"
if run; then ko "senza credenziali: esce"; else ok "senza credenziali: esce"; fi
check "senza credenziali: dice dove metterle" grep -q "manca .*/.env" "$tmp/out"
if run --boh; then ko "opzione sconosciuta: esce"; else ok "opzione sconosciuta: esce"; fi

[ "$fails" = 0 ] || {
  echo "$fails test falliti"
  exit 1
}
echo "tutti i test passati"
