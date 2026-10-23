#!/bin/sh
# Test di infra.sh (INFRA-001..004) con un docker finto: registra i comandi
# invece di eseguirli, così non serve il demone. Gira su una copia di
# infra/ in una cartella temporanea.
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

# Repo finto: infra.sh, infra/ senza .env, uno stack nuovo con regole
# ignote e uno senza .env.example.
repo=$tmp/repo
mkdir -p "$repo"
cp "$ROOT/infra.sh" "$repo/"
cp -r "$ROOT/infra" "$repo/"
rm -f "$repo"/infra/*/.env
mkdir -p "$repo/infra/aaa-nuovo" "$repo/infra/zzz-libero"
printf 'name: aaa-nuovo\nservices: {}\n' >"$repo/infra/aaa-nuovo/compose.yaml"
echo 'SEGRETO=cambiami' >"$repo/infra/aaa-nuovo/.env.example"
printf 'name: zzz-libero\nservices: {}\n' >"$repo/infra/zzz-libero/compose.yaml"
sed -i "s|^DOWNLOADS_DIR=.*|DOWNLOADS_DIR=$tmp/downloads|" "$repo/infra/torrent/.env.example"

# docker finto: scrive in $LOG "<cartella> <argomenti>". Le reti esistono
# solo dopo network create; ps elenca un container per gli stack in $UP.
bin=$tmp/bin
mkdir -p "$bin"
cat >"$bin/docker" <<'FAKE'
#!/bin/sh
echo "$(basename "$PWD") $*" >>"$LOG"
case "$1 ${2:-}" in
  "network inspect") [ -f "$STATE/net-$3" ] ;;
  "network create") touch "$STATE/net-$3" ;;
  "ps -a")
    for s in $UP; do
      case "$*" in *"project=$s "*) echo "$s-1" ;; esac
    done
    ;;
esac
FAKE
chmod +x "$bin/docker"
# tailscale finto: l'IP del server nella tailnet.
printf '#!/bin/sh\necho 100.64.0.7\n' >"$bin/tailscale"
chmod +x "$bin/tailscale"
export LOG="$tmp/log" STATE="$tmp" UP=""
PATH="$bin:$PATH"
export PATH

# Da root (con sudo) i file vanno all'utente che ha chiamato sudo.
owner=$(id -u)
if [ "$owner" -eq 0 ]; then
  owner=4242
  export SUDO_UID=4242 SUDO_GID=4242
fi

run() {
  : >"$LOG"
  "$repo/infra.sh" "$@" >"$tmp/out" 2>&1
}
# Gli stack su cui compose ha eseguito $1 (up/down), in ordine.
order() {
  sed -n "s/^\([a-z0-9-]*\) compose $1.*/\1/p" "$LOG" | tr '\n' ' '
}
envval() { sed -n "s/^$2=//p" "$repo/infra/$1/.env"; }

# INFRA-004: status non crea niente.
run status
check "status: nessun .env creato" test ! -f "$repo/infra/postgres/.env"
check "status: nessuna rete creata" sh -c "! grep -q 'network create' '$LOG'"
check "status: stack spenti" grep -q "postgres     spento" "$tmp/out"

# INFRA-001/002: primo avvio.
run up
check "up: termina senza errori" true
check "up: reti proxy e db create" sh -c "grep -q 'network create proxy' '$LOG' && grep -q 'network create db' '$LOG'"
check "up: ordine di avvio" test "$(order up)" = "postgres torrent glances webtop ron1nos monitoring updates proxy dns zzz-libero "
check "up: aspetta Postgres sano" grep -q "^postgres compose up .*--wait" "$LOG"
check "up: niente template" sh -c "! grep -q '^_app-template' '$LOG'"
check "up: stack senza regole né .env non avviato" grep -q "aaa-nuovo: manca .env" "$tmp/out"
for s in postgres torrent webtop ron1nos; do
  check "up: $s/.env con permessi 600" test "$(stat -c %a "$repo/infra/$s/.env")" = 600
done
check "up: niente password d'esempio" sh -c "! grep -q -E 'PASSWORD=(cambiami.*|admin)$' '$repo'/infra/*/.env"
db_pw=$(envval postgres RON1NOS_DB_PASSWORD)
check "up: DATABASE_URL usa la password di Postgres" \
  test "$(envval ron1nos DATABASE_URL)" = "postgres://ron1nos:$db_pw@postgres:5432/ron1nos"
check "up: stesse credenziali qBittorrent" test "$(envval ron1nos QBT_PASSWORD)" = "$(envval torrent QBT_PASSWORD)"
check "up: stesso utente qBittorrent" test "$(envval ron1nos QBT_USERNAME)" = "$(envval torrent QBT_USERNAME)"
check "up: DNS con l'IP Tailscale" test "$(envval dns TS_IP)" = 100.64.0.7
check "up: PUID dell'utente" test "$(envval torrent PUID)" = "$owner"
check "up: cartella dei download creata" test -d "$tmp/downloads"
check "up: dice dove sono le password" grep -q "Password generate" "$tmp/out"

# Rilancio: i .env restano com'erano.
before=$(cat "$repo"/infra/*/.env | cksum)
run up
check "rilancio: .env invariati" test "$(cat "$repo"/infra/*/.env | cksum)" = "$before"
check "rilancio: reti non ricreate" sh -c "! grep -q 'network create' '$LOG'"

# Solo alcuni stack, rimessi in ordine.
run up proxy postgres
check "up con nomi: solo quelli, in ordine" test "$(order up)" = "postgres proxy "
if run up nessuno; then ko "stack sconosciuto: errore"; else ok "stack sconosciuto: errore"; fi
check "stack sconosciuto: elenca i validi" grep -q "validi: postgres torrent" "$tmp/out"

# INFRA-003: spegnimento in ordine inverso, solo gli stack accesi.
UP="postgres torrent ron1nos proxy zzz-libero"
run down
check "down: ordine inverso" test "$(order down)" = "zzz-libero proxy ron1nos torrent postgres "
check "down: conserva i volumi" sh -c "! grep -q 'down.*-v' '$LOG'"
check "down: stack spento non è un errore" grep -q "webtop: già spento" "$tmp/out"
check "down: .env conservati" test -f "$repo/infra/postgres/.env"
run down ron1nos
check "down con nomi: solo quelli" test "$(order down)" = "ron1nos "

# Senza Tailscale il DNS non ha .env e non parte.
rm -f "$repo/infra/dns/.env" "$bin/tailscale"
run up dns
check "up senza Tailscale: niente .env del DNS" test ! -f "$repo/infra/dns/.env"
check "up senza Tailscale: lo dice" grep -q "dns: Tailscale non risponde" "$tmp/out"
check "up senza Tailscale: DNS non avviato" test -z "$(order up)"

# Docker che non risponde.
cat >"$bin/docker" <<'FAKE'
#!/bin/sh
[ "$1" = compose ] && exit 0
exit 1
FAKE
if run up; then ko "Docker spento: errore"; else ok "Docker spento: errore"; fi
check "Docker spento: dice cosa fare" grep -q "Docker non risponde" "$tmp/out"

if [ "$fails" -gt 0 ]; then
  echo "$fails test falliti"
  exit 1
fi
echo "tutti i test passati"
