#!/bin/sh
# Accende, spegne e mostra tutti gli stack di infra/ (INFRA-001..004).
#
#   ./infra.sh up [stack...]      avvia, anche la prima volta
#   ./infra.sh down [stack...]    spegne, conservando dati e .env
#   ./infra.sh status [stack...]  stato dei container
#
# Senza nomi agisce su tutti gli stack. Se il repo è di root, come in
# /opt/ron1n, va lanciato con sudo. Specifica: docs/specs/infra.md.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
INFRA=$ROOT/infra
# Ordine di avvio: Postgres prima di ron1nOS, Caddy per ultimo, così un
# servizio è raggiungibile solo quando c'è. Lo spegnimento va al contrario.
# Gli stack nuovi, non ancora qui, partono dopo questi in ordine alfabetico.
ORDER="postgres torrent glances webtop ron1nos monitoring updates proxy"
# Stack da aspettare finché il healthcheck è verde prima di passare al
# successivo.
WAIT="postgres"
NETWORKS="proxy db"

info() { printf '    %s\n' "$*"; }
step() { printf '\033[1;31m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\033[1;31merrore:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Uso: ./infra.sh <comando> [stack...]

  up      avvia gli stack; al primo avvio crea reti, .env e cartelle
  down    spegne gli stack; volumi, .env e reti restano
  status  mostra i container di ogni stack

Senza nomi agisce su tutti gli stack di infra/.
EOF
}

# docker compose dentro la cartella dello stack, così legge .env e
# compose.override.yaml.
compose() (
  cd "$INFRA/$1"
  shift
  docker compose "$@"
)

# Tutti gli stack nell'ordine di avvio: quelli di ORDER, poi gli altri.
# Le cartelle che iniziano con _ sono template.
all_stacks() {
  for s in $ORDER; do
    [ -f "$INFRA/$s/compose.yaml" ] && echo "$s"
  done
  for dir in "$INFRA"/*/; do
    s=$(basename "$dir")
    case $s in _*) continue ;; esac
    [ -f "$dir/compose.yaml" ] || continue
    case " $ORDER " in *" $s "*) continue ;; esac
    echo "$s"
  done
}

# Gli stack richiesti ($@), rimessi nell'ordine di avvio. Senza nomi, tutti.
select_stacks() {
  all=$(all_stacks)
  [ $# -gt 0 ] || {
    echo "$all"
    return 0
  }
  valid=$(echo "$all" | tr '\n' ' ')
  for want in "$@"; do
    case " $valid" in
      *" $want "*) ;;
      *) die "stack sconosciuto: $want (validi: ${valid% })" ;;
    esac
  done
  for s in $all; do
    for want in "$@"; do
      if [ "$s" = "$want" ]; then
        echo "$s"
        break
      fi
    done
  done
}

reverse() {
  out=
  for s in "$@"; do out="$s $out"; done
  echo "$out"
}

# Nome del progetto Compose: la chiave name: del compose, o la cartella.
project_name() {
  n=$(sed -n 's/^name: *//p' "$INFRA/$1/compose.yaml" | head -n 1)
  echo "${n:-$1}"
}

# Container dello stack $1, accesi o fermi, nel formato $2 di docker ps.
# Dalle etichette di Compose: non serve leggere compose.yaml né .env.
containers() {
  fmt='{{.ID}}'
  [ $# -lt 2 ] || fmt=$2
  docker ps -a --filter "label=com.docker.compose.project=$(project_name "$1")" --format "$fmt"
}

# Valore di KEY in un file .env (ultima occorrenza, senza commenti e
# senza apici singoli).
env_get() {
  sed -n "s/^$2=//p" "$1" | tail -n 1 | sed "s/^'\(.*\)'\$/\1/"
}

# Password casuale, solo esadecimale: sicura anche dentro un URL.
rand() {
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}

# Utente proprietario dei file degli stack: chi lancia lo script, o chi ha
# chiamato sudo. Da root senza sudo, il primo utente normale.
find_owner() {
  if [ "$(id -u)" -ne 0 ]; then
    OWNER_UID=$(id -u)
    OWNER_GID=$(id -g)
  elif [ -n "${SUDO_UID:-}" ] && [ "$SUDO_UID" -ne 0 ]; then
    OWNER_UID=$SUDO_UID
    OWNER_GID=${SUDO_GID:-$SUDO_UID}
  else
    line=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $3 ":" $4; exit }')
    OWNER_UID=${line%%:*}
    OWNER_GID=${line#*:}
    [ -n "$line" ] || {
      OWNER_UID=1000
      OWNER_GID=1000
    }
  fi
}

# Copia .env.example in .env sostituendo le chiavi date (KEY=VALORE ...).
# Un .env che esiste già non si tocca.
env_create() {
  dir=$1
  shift
  [ -f "$dir/compose.yaml" ] || return 0
  [ -f "$dir/.env" ] && return 0
  [ -f "$dir/.env.example" ] || die "manca $dir/.env.example"
  [ -w "$dir" ] || die "non posso scrivere in $dir: rilancia con sudo"
  tmp="$dir/.env.tmp"
  cp "$dir/.env.example" "$tmp"
  for kv in "$@"; do
    key=${kv%%=*}
    val=${kv#*=}
    grep -q "^$key=" "$tmp" || die "$key non è in $dir/.env.example"
    sed -i "s|^$key=.*|$key=$val|" "$tmp"
  done
  chmod 600 "$tmp"
  [ "$(id -u)" -ne 0 ] || chown "$OWNER_UID:$OWNER_GID" "$tmp"
  mv "$tmp" "$dir/.env"
  CREATED="$CREATED $(basename "$dir")"
  info "$(basename "$dir")/.env creato"
}

# Genera i .env mancanti degli stack noti, con i valori condivisi coerenti:
# password di ron1nos in Postgres = DATABASE_URL, credenziali qBittorrent
# uguali in torrent e ron1nos, IP Tailscale del server per il DNS.
make_envs() {
  env_create "$INFRA/postgres" \
    "POSTGRES_PASSWORD=$(rand)" \
    "RON1NOS_DB_PASSWORD=$(rand)"

  env_create "$INFRA/torrent" \
    "PUID=$OWNER_UID" "PGID=$OWNER_GID" \
    "QBT_PASSWORD=$(rand)"

  env_create "$INFRA/webtop" \
    "PUID=$OWNER_UID" "PGID=$OWNER_GID" \
    "PASSWORD=$(rand)"

  if [ -f "$INFRA/ron1nos/compose.yaml" ] && [ ! -f "$INFRA/ron1nos/.env" ]; then
    if [ ! -f "$INFRA/postgres/.env" ] || [ ! -f "$INFRA/torrent/.env" ]; then
      die "per creare ron1nos/.env servono postgres/.env e torrent/.env"
    fi
    db_pw=$(env_get "$INFRA/postgres/.env" RON1NOS_DB_PASSWORD)
    qbt_user=$(env_get "$INFRA/torrent/.env" QBT_USERNAME)
    qbt_pw=$(env_get "$INFRA/torrent/.env" QBT_PASSWORD)
    env_create "$INFRA/ron1nos" \
      "QBT_USERNAME=$qbt_user" \
      "QBT_PASSWORD=$qbt_pw" \
      "DATABASE_URL=postgres://ron1nos:$db_pw@postgres:5432/ron1nos"
  fi

  if [ -f "$INFRA/dns/compose.yaml" ] && [ ! -f "$INFRA/dns/.env" ]; then
    ts_ip=$(tailscale ip -4 2>/dev/null | head -n 1) || ts_ip=
    if [ -n "$ts_ip" ]; then
      env_create "$INFRA/dns" "TS_IP=$ts_ip"
    else
      info "dns: Tailscale non risponde, niente .env (scrivi TS_IP in infra/dns/.env)"
    fi
  fi
}

# Cartella dei download di qBittorrent, di proprietà dell'utente degli stack.
make_downloads_dir() {
  [ -f "$INFRA/torrent/.env" ] || return 0
  dl=$(env_get "$INFRA/torrent/.env" DOWNLOADS_DIR)
  dl=${dl:-/srv/downloads}
  [ -d "$dl" ] && return 0
  mkdir -p "$dl" 2>/dev/null ||
    die "non posso creare $dl: rilancia con sudo, oppure sudo mkdir -p $dl && sudo chown $OWNER_UID:$OWNER_GID $dl"
  [ "$(id -u)" -ne 0 ] || chown "$OWNER_UID:$OWNER_GID" "$dl"
  info "$dl creata"
}

check_docker() {
  command -v docker >/dev/null || die "Docker non è installato: vedi docs/server-setup.md"
  docker compose version >/dev/null 2>&1 || die "manca il plugin docker compose (pacchetto docker-compose-plugin)"
  docker info >/dev/null 2>&1 ||
    die "Docker non risponde: avvialo (sudo systemctl start docker), oppure lancia con sudo o da un utente del gruppo docker"
}

make_networks() {
  for net in $NETWORKS; do
    docker network inspect "$net" >/dev/null 2>&1 && continue
    docker network create "$net" >/dev/null
    info "rete $net creata"
  done
}

cmd_up() {
  stacks=$(select_stacks "$@")
  check_docker
  find_owner
  CREATED=

  step "Preparazione"
  make_networks
  make_envs
  make_downloads_dir

  step "Avvio"
  started=
  for s in $stacks; do
    dir=$INFRA/$s
    if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
      info "$s: manca .env, non lo avvio (copia .env.example in .env, adattalo e rilancia)"
      continue
    fi
    info "$s"
    wait_flags=
    case " $WAIT " in *" $s "*) wait_flags="--wait --wait-timeout 180" ;; esac
    # shellcheck disable=SC2086 # wait_flags va diviso in parole
    compose "$s" up -d --quiet-pull --remove-orphans $wait_flags ||
      die "lo stack $s non è partito: ./infra.sh status $s, poi docker compose -f infra/$s/compose.yaml logs"
    started="$started $s"
  done

  # shellcheck disable=SC2086 # un nome di stack per parola
  [ -z "$started" ] || cmd_status $started
  if [ -n "$CREATED" ]; then
    echo
    info "Password generate nei .env di:$CREATED (cartelle in infra/)."
  fi
}

cmd_down() {
  stacks=$(select_stacks "$@")
  check_docker
  step "Spegnimento"
  # shellcheck disable=SC2086 # un nome di stack per parola
  for s in $(reverse $stacks); do
    dir=$INFRA/$s
    # Senza .env lo stack non è mai partito, e compose non legge il file.
    if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
      info "$s: mai avviato"
      continue
    fi
    if [ -z "$(containers "$s")" ]; then
      info "$s: già spento"
      continue
    fi
    info "$s"
    compose "$s" down --remove-orphans || die "lo stack $s non si è spento"
  done
}

cmd_status() {
  stacks=$(select_stacks "$@")
  check_docker
  step "Stato"
  for s in $stacks; do
    rows=$(containers "$s" '{{.Names}}\t{{.Status}}')
    if [ -z "$rows" ]; then
      printf '    %-12s spento\n' "$s"
    else
      echo "$rows" | while IFS="$(printf '\t')" read -r name st; do
        printf '    %-12s %-28s %s\n' "$s" "$name" "$st"
      done
    fi
  done
}

main() {
  [ $# -gt 0 ] || {
    usage
    exit 1
  }
  cmd=$1
  shift
  case $cmd in
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    status) cmd_status "$@" ;;
    -h | --help | help) usage ;;
    *)
      usage >&2
      die "comando sconosciuto: $cmd"
      ;;
  esac
}

# INFRA_LIB=1 carica solo le funzioni, per i test.
if [ "${INFRA_LIB:-0}" != 1 ]; then
  main "$@"
fi
