#!/bin/sh
# Test della scelta delle voci di bootstrap.sh (SETUP-013): opzioni,
# variabili d'ambiente, default in WSL e dipendenze. Carica solo le
# funzioni, senza toccare il sistema.
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

# Le voci scelte con gli argomenti in $ARGS (una parola ciascuno) e le
# variabili date, o "errore". Ogni prova in una shell nuova, con solo le
# variabili che le passa env.
voci() {
  # ARGS va diviso in parole; il codice tra apici gira nella shell figlia.
  # shellcheck disable=SC2086,SC2016
  env -i PATH="$PATH" RON1N_BOOTSTRAP_LIB=1 RON1N_WSL="${WSL:-0}" "$@" \
    sh -c '
    . "$0"
    parse_args "$@"
    echo "$SCELTE|$CHIEDI"
  ' "$ROOT/scripts/bootstrap.sh" ${ARGS:-} 2>/dev/null || echo errore
}

expect() {
  desc=$1
  want=$2
  shift 2
  got=$(voci "$@")
  if [ "$got" = "$want" ]; then ok "$desc"; else ko "$desc: atteso '$want', avuto '$got'"; fi
}

tutte="aggiornamenti docker gruppi tailscale ssh firewall repo env stack"

expect "senza opzioni: tutte, con il menu" "$tutte|1"
senza_ts_ssh="aggiornamenti docker gruppi firewall repo env stack|0"
ARGS=--yes expect "--yes: tutte, senza menu" "$tutte|0"
ARGS="--skip tailscale,ssh" expect "--skip con virgole" "$senza_ts_ssh"
ARGS=--skip=tailscale,ssh expect "--skip=..." "$senza_ts_ssh"
ARGS="--skip tailscale --skip ssh" expect "--skip ripetuto" "$senza_ts_ssh"
ARGS="--only stack,repo" expect "--only, nell'ordine di esecuzione" "repo stack|0"
ARGS="--only repo,stack --skip stack" expect "--only e --skip insieme" "repo|0"
expect "RON1N_SKIP" "aggiornamenti docker gruppi tailscale firewall repo env stack|0" \
  RON1N_SKIP=ssh
expect "RON1N_ONLY con spazi" "docker stack|0" RON1N_ONLY="stack docker"
expect "RON1N_SKIP_TAILSCALE=1 come prima" \
  "aggiornamenti docker gruppi ssh firewall repo env stack|0" RON1N_SKIP_TAILSCALE=1
ARGS="--skip tailscal" expect "voce sconosciuta" "errore"
ARGS=--boh expect "opzione sconosciuta" "errore"
ARGS=--skip expect "--skip senza elenco" "errore"
WSL=1 expect "WSL: senza tailscale, ssh e firewall" \
  "aggiornamenti docker gruppi repo env stack|1"
WSL=1 ARGS="--only ssh" expect "WSL con --only: si può chiedere ssh" "ssh|0"

if ARGS=--help voci | grep -q '^Uso: bootstrap.sh'; then ok "--help"; else ko "--help"; fi

# Dipendenze: env e stack vogliono il repo, stack vuole docker.
dipendenze() {
  # shellcheck disable=SC2016 # gira nella shell figlia
  env -i PATH="$PATH" TESTPATH="$1" RON1N_BOOTSTRAP_LIB=1 RON1N_DIR="$tmp/repo" SCELTE="$2" sh -c '
    . "$0"
    PATH=$TESTPATH
    has_systemd() { return 0; }
    check_voci >/dev/null
    echo "$SCELTE"
  ' "$ROOT/scripts/bootstrap.sh" 2>/dev/null || echo errore
}

expect_dip() {
  got=$(dipendenze "$2" "$3")
  if [ "$got" = "$4" ]; then ok "$1"; else ko "$1: atteso '$4', avuto '$got'"; fi
}

nodocker=$tmp/bin
mkdir -p "$nodocker"
for c in sh sed tr grep cat env; do ln -s "$(command -v "$c")" "$nodocker/$c"; done
withdocker=$tmp/bin2
cp -a "$nodocker" "$withdocker"
printf '#!/bin/sh\n' >"$withdocker/docker"
chmod +x "$withdocker/docker"

expect_dip "stack senza repo né voce repo" "$withdocker" "stack" "errore"
expect_dip "stack con la voce repo" "$withdocker" "repo stack" "repo stack"
mkdir -p "$tmp/repo/.git"
expect_dip "stack con il repo già clonato" "$withdocker" "stack" "stack"
expect_dip "stack senza docker" "$nodocker" "stack" "errore"
expect_dip "stack con la voce docker" "$nodocker" "docker stack" "docker stack"
expect_dip "nessuna voce" "$withdocker" "" "errore"

if [ "$fails" -gt 0 ]; then
  echo "$fails test falliti"
  exit 1
fi
echo "tutti i test passati"
