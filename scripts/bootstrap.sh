#!/bin/sh
# Setup del mini PC ron1n: da Debian 13 appena installato (solo curl) allo
# stack di infra/ avviato e raggiungibile dalla tailnet.
#
#   curl -fsSL https://raw.githubusercontent.com/1r0n51uv/ron1n/main/scripts/bootstrap.sh | sh
#
# Da root (`su -`). Prima chiede cosa configurare, poi i valori dei .env
# degli stack (invio = default, password casuali). Si può rilanciare: rifà
# solo ciò che manca, non tocca i .env esistenti né i dati degli stack.
# Niente backup, per scelta. Opzioni e voci: --help (SETUP-013).
set -eu

RON1N_REPO=${RON1N_REPO:-https://github.com/1r0n51uv/ron1n}
RON1N_BRANCH=${RON1N_BRANCH:-main}
RON1N_DIR=${RON1N_DIR:-/opt/ron1n}

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
export DEBIAN_FRONTEND=noninteractive

step() { printf '\n\033[1;31m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die() {
  printf '\n\033[1;31merrore:\033[0m %s\n' "$*" >&2
  exit 1
}

apt_install() {
  apt-get install -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@" </dev/null
}

# docker compose dentro la cartella dello stack, così legge anche .env e
# compose.override.yaml.
compose() (
  cd "$1"
  shift
  docker compose "$@"
)

# Valore di KEY in un file .env (ultima occorrenza, senza commenti e
# senza apici singoli).
env_get() {
  sed -n "s/^$2=//p" "$1" | tail -n 1 | sed "s/^'\(.*\)'\$/\1/"
}

# Password casuale, solo esadecimale: sicura anche dentro un URL.
rand() {
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}

# Le voci che si possono scegliere (SETUP-013), nell'ordine in cui girano.
# Controllo del sistema e pacchetti di base si fanno sempre.
VOCI="aggiornamenti docker gruppi tailscale ssh firewall repo env stack"

usage() {
  cat <<'EOF'
Uso: bootstrap.sh [--skip voci] [--only voci] [--yes]

Con un terminale e senza opzioni chiede le voci una alla volta.

  --skip a,b   salta queste voci (anche RON1N_SKIP=a,b)
  --only a,b   fa solo queste voci (anche RON1N_ONLY=a,b)
  --yes        niente menu: le voci di default, meno quelle saltate

Voci:
  aggiornamenti  aggiornamenti di sicurezza automatici
  docker         Docker Engine e Compose
  gruppi         utente amministratore in sudo e docker
  tailscale      Tailscale con Tailscale SSH (serve systemd)
  ssh            niente login di root né password se c'è una chiave
  firewall       ufw e filtro delle porte dei container
  repo           clone o aggiornamento del repo
  env            i .env degli stack chiesti sul terminale
  stack          avvio di tutto con ./infra.sh up

Di default tutte; in WSL senza tailscale, ssh e firewall.

Con curl: curl -fsSL .../bootstrap.sh | sh -s -- --skip tailscale,ssh

Variabili d'ambiente facoltative:
  RON1N_USER    utente amministratore (default: il primo con UID >= 1000)
  TS_AUTHKEY    chiave Tailscale; senza, lo script mostra il link di login
  RON1N_REPO    repo da clonare (default: https://github.com/1r0n51uv/ron1n)
  RON1N_BRANCH  branch (default: main)
  RON1N_DIR     cartella del repo (default: /opt/ron1n)
  RON1N_WSL     1 o 0 al posto del riconoscimento di WSL
  RON1N_SKIP_TAILSCALE=1  come --skip tailscale
EOF
}

describe_voce() {
  case $1 in
    aggiornamenti) echo "Aggiornamenti di sicurezza automatici" ;;
    docker) echo "Docker Engine e Compose" ;;
    gruppi) echo "Utente amministratore in sudo e docker" ;;
    tailscale) echo "Tailscale con Tailscale SSH" ;;
    ssh) echo "Regole SSH (niente root, niente password con una chiave)" ;;
    firewall) echo "Firewall ufw" ;;
    repo) echo "Repo in $RON1N_DIR" ;;
    env) echo "I .env degli stack, chiesti qui" ;;
    stack) echo "Avvio degli stack" ;;
  esac
}

is_wsl() {
  case ${RON1N_WSL:-} in
    1) return 0 ;;
    0) return 1 ;;
  esac
  [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

has_systemd() { [ -d /run/systemd/system ]; }

# Avvia e abilita un servizio; senza systemd (WSL) con service.
start_service() {
  if has_systemd; then
    systemctl enable --now "$1" >/dev/null
  else
    service "$1" start >/dev/null 2>&1 || info "non riesco ad avviare $1: senza systemd va avviato a mano"
  fi
}

in_list() {
  case " $2 " in *" $1 "*) return 0 ;; esac
  return 1
}

scelta() { in_list "$1" "$SCELTE"; }

# Le voci di $2 nell'ordine di VOCI, meno quelle di $3.
voci_filtra() {
  out=
  for v in $VOCI; do
    if in_list "$v" "$1" && ! in_list "$v" "${2:-}"; then out="$out $v"; fi
  done
  echo "${out# }"
}

# Un elenco con virgole o spazi, controllato: una voce sconosciuta ferma
# tutto prima di toccare qualcosa.
parse_voci() {
  out=
  for v in $(printf '%s' "$1" | tr ',' ' '); do
    in_list "$v" "$VOCI" || die "voce sconosciuta: $v (voci: $VOCI)"
    out="$out $v"
  done
  echo "${out# }"
}

default_voci() {
  if is_wsl; then
    voci_filtra "$VOCI" "tailscale ssh firewall"
  else
    echo "$VOCI"
  fi
}

# Opzioni e variabili d'ambiente in SCELTE; CHIEDI=1 se va mostrato il
# menu (nessuna scelta esplicita).
parse_args() {
  only=${RON1N_ONLY:-}
  skip=${RON1N_SKIP:-}
  [ "${RON1N_SKIP_TAILSCALE:-0}" != 1 ] || skip="$skip,tailscale"
  yes=0
  while [ $# -gt 0 ]; do
    case $1 in
      -y | --yes) yes=1 ;;
      --only | --skip)
        [ $# -ge 2 ] || die "$1 vuole un elenco di voci (vedi --help)"
        if [ "$1" = --only ]; then only="$only,$2"; else skip="$skip,$2"; fi
        shift
        ;;
      --only=*) only="$only,${1#*=}" ;;
      --skip=*) skip="$skip,${1#*=}" ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "opzione sconosciuta: $1 (vedi --help)" ;;
    esac
    shift
  done
  only=$(parse_voci "$only") || exit 1
  skip=$(parse_voci "$skip") || exit 1
  CHIEDI=1
  [ "$yes" = 0 ] && [ -z "$only" ] && [ -z "$skip" ] || CHIEDI=0
  if [ -n "$only" ]; then
    SCELTE=$(voci_filtra "$only" "$skip")
  else
    SCELTE=$(voci_filtra "$(default_voci)" "$skip")
  fi
}

# Il menu: una domanda per voce, col default già scelto.
choose() {
  [ "$CHIEDI" = 1 ] && have_tty || return 0
  step "Cosa configuro"
  info "Rispondi s o n; invio = il valore tra parentesi."
  nuove=
  for v in $VOCI; do
    d=n
    ! scelta "$v" || d=s
    ask "$(describe_voce "$v")? (s/n)" "$d"
    case $REPLY in
      s | S | si | sì) nuove="$nuove $v" ;;
    esac
  done
  SCELTE=${nuove# }
}

# Le dipendenze fra le voci, prima di cominciare.
check_voci() {
  step "Voci"
  if scelta tailscale && ! has_systemd; then
    info "tailscale saltata: serve systemd"
    SCELTE=$(voci_filtra "$SCELTE" tailscale)
  fi
  [ -n "$SCELTE" ] || die "nessuna voce scelta, non ho toccato niente"
  for v in env stack; do
    if scelta "$v" && ! scelta repo && [ ! -d "$RON1N_DIR/.git" ]; then
      die "$v vuole il repo in $RON1N_DIR: aggiungi la voce repo"
    fi
  done
  if scelta stack && ! scelta docker && ! command -v docker >/dev/null; then
    die "stack vuole Docker: aggiungi la voce docker"
  fi
  info "faccio: $SCELTE"
  saltate=$(voci_filtra "$VOCI" "$SCELTE")
  [ -z "$saltate" ] || info "salto: $saltate"
}

check_system() {
  step "Controllo del sistema"
  [ "$(id -u)" -eq 0 ] || die "va eseguito da root: su - poi rilancia il comando"
  [ -r /etc/os-release ] || die "non trovo /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != debian ] || [ "${VERSION_CODENAME:-}" != trixie ]; then
    die "serve Debian 13 (trixie), qui c'è ${PRETTY_NAME:-un sistema sconosciuto}"
  fi
  [ "$(dpkg --print-architecture)" = amd64 ] || die "serve un sistema amd64"
  info "${PRETTY_NAME}"
  ! is_wsl || info "WSL: tailscale, ssh e firewall spente di default"
  has_systemd || info "senza systemd: i servizi partono con service"
}

find_user() {
  step "Utente amministratore"
  if [ -n "${RON1N_USER:-}" ]; then
    ADMIN=$RON1N_USER
  else
    ADMIN=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
  fi
  [ -n "$ADMIN" ] || die "nessun utente normale: crealo con adduser <nome>, oppure indica RON1N_USER"
  getent passwd "$ADMIN" >/dev/null || die "l'utente $ADMIN non esiste"
  ADMIN_UID=$(id -u "$ADMIN")
  ADMIN_GID=$(id -g "$ADMIN")
  ADMIN_HOME=$(getent passwd "$ADMIN" | cut -d: -f6)
  info "$ADMIN (uid $ADMIN_UID, gid $ADMIN_GID)"
}

install_base() {
  step "Pacchetti base"
  apt-get update -q </dev/null
  apt_install ca-certificates curl git jq sudo openssl lm-sensors
}

setup_updates() {
  step "Aggiornamenti automatici"
  apt_install unattended-upgrades
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  info "aggiornamenti di sicurezza automatici attivi"
}

# Dati di Docker e containerd sul disco di /srv, se è un filesystem diverso
# da /var (SETUP-007): bind mount in /etc/fstab, prima che Docker parta.
# Docker 29 tiene le immagini nello snapshotter di containerd, per questo
# servono tutte e due le cartelle. I dati già esistenti non si spostano.
docker_on_srv() {
  [ -d /srv ] && [ -d /var ] || return 0
  if [ "$(stat -c %d /srv)" = "$(stat -c %d /var)" ]; then
    info "/srv e /var sono sullo stesso disco: i dati di Docker restano in /var/lib"
    return 0
  fi
  for d in docker containerd; do
    target=/var/lib/$d
    if grep -q "^/srv/$d $target " /etc/fstab; then
      mountpoint -q "$target" || mount "$target"
      continue
    fi
    if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
      info "$target ha già dei dati: lo lascio dov'è (per spostarlo vedi docs/server-setup.md)"
      continue
    fi
    mkdir -p "/srv/$d" "$target"
    echo "/srv/$d $target none bind,x-systemd.requires-mounts-for=/srv 0 0" >>/etc/fstab
    mount "$target"
    info "$target su /srv/$d"
  done
  ! has_systemd || systemctl daemon-reload
}

install_docker() {
  step "Docker Engine e Compose"
  docker_on_srv
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -s /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  cat >/etc/apt/sources.list.d/docker.sources <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  # Log dei container a rotazione: al massimo 3 file da 10 MB ciascuno.
  mkdir -p /etc/docker
  if [ ! -f /etc/docker/daemon.json ]; then
    cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  fi
  apt-get update -q </dev/null
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  start_service docker
  info "$(docker --version)"
  info "$(docker compose version)"
}

setup_user() {
  step "Gruppi dell'utente"
  groups=sudo
  ! getent group docker >/dev/null || groups=sudo,docker
  usermod -aG "$groups" "$ADMIN"
  info "$ADMIN è in $groups (vale dal prossimo login)"
}

install_tailscale() {
  step "Tailscale"
  if ! command -v tailscale >/dev/null; then
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
      -o /etc/apt/sources.list.d/tailscale.list
    apt-get update -q </dev/null
    apt_install tailscale
  fi
  systemctl enable --now tailscaled >/dev/null
  if tailscale ip -4 >/dev/null 2>&1; then
    info "già nella tailnet: $(tailscale ip -4)"
    return 0
  fi
  if [ -n "${TS_AUTHKEY:-}" ]; then
    tailscale up --ssh --hostname=ron1n --auth-key="$TS_AUTHKEY"
  else
    info "apri il link che compare qui sotto per aggiungere il server alla tailnet"
    tailscale up --ssh --hostname=ron1n
  fi
  info "nella tailnet: $(tailscale ip -4)"
}

setup_ssh() {
  step "SSH"
  if [ ! -d /etc/ssh/sshd_config.d ]; then
    info "server SSH non installato, salto"
    return 0
  fi
  conf=/etc/ssh/sshd_config.d/10-ron1n.conf
  echo "PermitRootLogin no" >"$conf.tmp"
  if [ -s "$ADMIN_HOME/.ssh/authorized_keys" ]; then
    echo "PasswordAuthentication no" >>"$conf.tmp"
    info "login con password spento: $ADMIN ha una chiave"
  else
    info "login con password lasciato acceso: copia una chiave con ssh-copy-id e rilancia"
  fi
  mv "$conf.tmp" "$conf"
  sshd -t || die "configurazione SSH non valida, controlla $conf"
  if has_systemd; then
    systemctl reload ssh
  else
    service ssh reload >/dev/null 2>&1 || info "SSH non è attivo: le regole valgono al prossimo avvio"
  fi
}

setup_firewall() {
  step "Firewall"
  command -v ufw >/dev/null || apt_install ufw
  ext_if=$(ip route show default | awk '{ print $5; exit }')
  [ -n "$ext_if" ] || die "non trovo l'interfaccia di rete principale"
  torrent_port=6881
  if [ -f "$RON1N_DIR/infra/torrent/.env" ]; then
    p=$(env_get "$RON1N_DIR/infra/torrent/.env" TORRENTING_PORT)
    [ -n "$p" ] && torrent_port=$p
  fi

  # Docker pubblica le porte scavalcando ufw: il filtro per i container
  # sta nella catena DOCKER-USER. Da $ext_if (LAN e internet) passano solo
  # le risposte e la porta BitTorrent; dalla tailnet passa tutto.
  rules=/etc/ufw/after.rules
  sed -i '/^# BEGIN ron1n DOCKER-USER/,/^# END ron1n DOCKER-USER/d' "$rules"
  cat >>"$rules" <<EOF
# BEGIN ron1n DOCKER-USER
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -i $ext_if -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -i $ext_if -p tcp --dport $torrent_port -j RETURN
-A DOCKER-USER -i $ext_if -p udp --dport $torrent_port -j RETURN
-A DOCKER-USER -i $ext_if -j DROP
COMMIT
# END ron1n DOCKER-USER
EOF

  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp comment ssh >/dev/null
  ufw allow in on tailscale0 comment tailnet >/dev/null
  # Glances ascolta sull'IP di docker0: lo chiamano Caddy e ron1nOS.
  ufw allow proto tcp from 172.16.0.0/12 to 172.17.0.1 port 61208 comment glances >/dev/null
  ufw --force enable >/dev/null
  ufw reload >/dev/null
  info "aperti: ssh, tailnet, BitTorrent $torrent_port; porte dei container solo dalla tailnet ($ext_if filtrata)"
}

# Un comando come $ADMIN, con la sua home (git legge lì la configurazione).
as_admin() {
  runuser -u "$ADMIN" -- env HOME="$ADMIN_HOME" "$@"
}

# Il repo è di $ADMIN (SETUP-012): git e infra.sh senza sudo. Un repo
# clonato da root da un bootstrap vecchio passa a $ADMIN.
clone_repo() {
  step "Repo ron1n in $RON1N_DIR"
  if [ -d "$RON1N_DIR/.git" ]; then
    chown -R "$ADMIN_UID:$ADMIN_GID" "$RON1N_DIR"
    [ -z "$(as_admin git -C "$RON1N_DIR" status --porcelain --untracked-files=no)" ] ||
      die "$RON1N_DIR ha modifiche locali: sistemale (git -C $RON1N_DIR status) e rilancia"
    as_admin git -C "$RON1N_DIR" fetch -q origin "$RON1N_BRANCH"
    as_admin git -C "$RON1N_DIR" checkout -q "$RON1N_BRANCH"
    as_admin git -C "$RON1N_DIR" merge -q --ff-only "origin/$RON1N_BRANCH" ||
      die "$RON1N_DIR non si aggiorna con fast-forward"
    info "aggiornato a $(as_admin git -C "$RON1N_DIR" rev-parse --short HEAD)"
  else
    install -d -o "$ADMIN_UID" -g "$ADMIN_GID" "$RON1N_DIR"
    as_admin git clone -q --branch "$RON1N_BRANCH" "$RON1N_REPO" "$RON1N_DIR"
    info "clonato a $(as_admin git -C "$RON1N_DIR" rev-parse --short HEAD)"
  fi
  info "di $ADMIN: git pull e ./infra.sh senza sudo"
}

# Con curl | sh lo stdin è lo script: le risposte si leggono da /dev/tty.
have_tty() { (: </dev/tty) 2>/dev/null; }

# Domanda $1 con risposta in REPLY; invio = $2.
ask() {
  if [ -n "$2" ]; then
    printf '    %s [%s]: ' "$1" "$2" >/dev/tty
  else
    printf '    %s: ' "$1" >/dev/tty
  fi
  IFS= read -r REPLY </dev/tty || REPLY=
  [ -n "$REPLY" ] || REPLY=$2
}

# Come ask, senza eco e senza default.
ask_secret() {
  printf '    %s: ' "$1" >/dev/tty
  stty -echo </dev/tty
  IFS= read -r REPLY </dev/tty || REPLY=
  stty echo </dev/tty
  printf '\n' >/dev/tty
}

# Password nuova in REPLY, scritta due volte. $2 dice cosa fa l'invio:
# casuale (una password generata), vuota, o niente (va scritta). $3 è la
# lunghezza minima; con $4 = url solo caratteri che stanno in un URL.
ask_password() {
  while :; do
    ask_secret "$1"
    if [ -z "$REPLY" ]; then
      case $2 in
        casuale) REPLY=$(rand) && return 0 ;;
        vuota) return 0 ;;
      esac
      info "serve una password"
      continue
    fi
    pw=$REPLY
    if [ "${#pw}" -lt "$3" ]; then
      info "almeno $3 caratteri, riprova"
      continue
    fi
    case $pw in
      *"'"*)
        info "niente apici singoli, riprova"
        continue
        ;;
    esac
    if [ "${4:-}" = url ]; then
      case $pw in
        *[!A-Za-z0-9._~-]*)
          info "solo lettere, cifre e . _ ~ - (finisce in DATABASE_URL), riprova"
          continue
          ;;
      esac
    fi
    ask_secret "Ripeti"
    [ "$REPLY" = "$pw" ] && return 0
    info "non coincidono, riprova"
  done
}

# Valore pronto per il .env: tra apici singoli se contiene caratteri che
# Compose interpreterebbe ($, spazi, #...).
env_quote() {
  case $1 in
    *[!A-Za-z0-9_./:@+=,-]*) printf "'%s'" "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Mette KEY=VALORE ($2=$3) nel file $1, al posto della riga KEY= o di
# quella commentata "# KEY=".
env_set() {
  K=$2 V=$3 awk '
    !done && ($0 ~ "^" ENVIRON["K"] "=" || $0 ~ "^# *" ENVIRON["K"] "=") {
      print ENVIRON["K"] "=" ENVIRON["V"]; done = 1; next
    }
    { print }' "$1" >"$1.new"
  mv "$1.new" "$1"
}

# I commenti subito sopra KEY ($2) nel file $1: la spiegazione della voce.
env_help() {
  awk -v k="$2" '
    $0 ~ "^" k "=" { printf "%s", buf; exit }
    /^#/ { sub(/^# ?/, ""); buf = buf "      " $0 "\n"; next }
    { buf = "" }' "$1"
}

# Hash per AUTH_PASSWORD_HASH nel formato di ron1nOS
# (server/auth/password.ts): scrypt$N$r$p$sale$hash, sale e hash in base64.
# La password passa per un argomento di openssl solo per un istante, su un
# server dove c'è solo root.
scrypt_hash() {
  salt=$(openssl rand -base64 16)
  hex=$(printf '%s' "$salt" | base64 -d | od -An -tx1 | tr -d ' \n')
  hash=$(openssl kdf -keylen 32 -kdfopt "pass:$1" -kdfopt "hexsalt:$hex" \
    -kdfopt n:32768 -kdfopt r:8 -kdfopt p:1 -kdfopt maxmem_bytes:67108864 \
    -binary SCRYPT | base64)
  # shellcheck disable=SC2016 # i $ sono del formato, non variabili
  printf 'scrypt$32768$8$1$%s$%s' "$salt" "$hash"
}

# Le voci di ron1nOS commentate in .env.example: login, Documenti, YAZIO.
ask_ron1nos() {
  f=$1
  ask_password "Password della dashboard, almeno 12 caratteri (invio = login spento)" vuota 12
  if [ -n "$REPLY" ]; then
    env_set "$f" AUTH_PASSWORD_HASH "$(env_quote "$(scrypt_hash "$REPLY")")"
    ask "Modulo Documenti, con una chiave di cifratura generata? (s/n)" s
    case $REPLY in
      s | S | si | sì)
        env_set "$f" DOCUMENTS_KEY "$(openssl rand -base64 32)"
        DOCUMENTS_KEY_NEW=1
        ;;
    esac
  fi
  ask "Email dell'account YAZIO (invio = sincronizzazione spenta)" ""
  [ -n "$REPLY" ] || return 0
  env_set "$f" YAZIO_USERNAME "$(env_quote "$REPLY")"
  ask_password "Password di YAZIO" "" 1
  env_set "$f" YAZIO_PASSWORD "$(env_quote "$REPLY")"
  for key in YAZIO_CLIENT_ID YAZIO_CLIENT_SECRET; do
    env_set "$f" "$key" "$(sed -n "s/^# *$key=//p" "$f")"
  done
  env_set "$f" YAZIO_TOKEN_KEY "$(openssl rand -base64 32)"
}

# Il .env di uno stack: ogni voce di .env.example, col suo valore come
# default. Utente, gruppo e i valori condivisi con altri stack non si
# chiedono: si riprendono, così sono coerenti.
ask_stack_env() {
  dir=$INFRA_DIR/$1
  tmp=$dir/.env.tmp
  echo
  info "$1"
  cp "$dir/.env.example" "$tmp"
  # Le chiavi prima del ciclo, che riscrive il file. Una per parola.
  # shellcheck disable=SC2013
  for key in $(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$tmp"); do
    case $1:$key in
      *:PUID) val=$ADMIN_UID ;;
      *:PGID) val=$ADMIN_GID ;;
      *:TZ)
        [ -n "${STACK_TZ:-}" ] || {
          ask "Fuso orario" "$(env_get "$tmp" TZ)"
          STACK_TZ=$REPLY
        }
        val=$STACK_TZ
        ;;
      ron1nos:QBT_URL) continue ;;
      ron1nos:QBT_USERNAME | ron1nos:QBT_PASSWORD)
        val=$(env_get "$INFRA_DIR/torrent/.env" "$key")
        ;;
      ios:GITHUB_TOKEN | tunnel:TUNNEL_TOKEN)
        env_help "$tmp" "$key" >/dev/tty
        ask_secret "$key (invio = vuoto)"
        val=$REPLY
        ;;
      ios:IOS_URL)
        # Dal dominio di Caddy, se il suo .env c'è già.
        d=$(env_get "$INFRA_DIR/proxy/.env" DOMINIO 2>/dev/null) || d=
        val=$(env_get "$tmp" "$key")
        [ -z "$d" ] || val=https://ios.$d
        ;;
      ron1nos:DATABASE_URL)
        val="postgres://ron1nos:$(env_get "$INFRA_DIR/postgres/.env" RON1NOS_DB_PASSWORD)@postgres:5432/ron1nos"
        ;;
      *PASSWORD*)
        env_help "$tmp" "$key" >/dev/tty
        url=
        [ "$1" != postgres ] || url=url
        ask_password "$key (invio = casuale)" casuale 1 "$url"
        val=$REPLY
        ;;
      *)
        env_help "$tmp" "$key" >/dev/tty
        ask "$key" "$(env_get "$tmp" "$key")"
        val=$REPLY
        ;;
    esac
    env_set "$tmp" "$key" "$(env_quote "$val")"
  done
  if [ "$1" = ron1nos ]; then ask_ron1nos "$tmp"; fi
  chmod 600 "$tmp"
  chown "$ADMIN_UID:$ADMIN_GID" "$tmp"
  mv "$tmp" "$dir/.env"
  info "$dir/.env scritto"
}

# I .env mancanti, chiesti sul terminale prima del primo avvio. Quelli che
# ci sono già non si toccano; senza terminale li crea infra.sh con password
# casuali.
ask_envs() {
  step "Configurazione degli stack"
  INFRA_DIR=$RON1N_DIR/infra
  missing=
  for dir in "$INFRA_DIR"/*/; do
    s=$(basename "$dir")
    case $s in _*) continue ;; esac
    if [ -f "$dir/compose.yaml" ] && [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
      missing="$missing $s"
    fi
  done
  if [ -z "$missing" ]; then
    info "i .env ci sono già, non li tocco"
    return 0
  fi
  if ! have_tty; then
    info "nessun terminale: i .env li crea infra.sh con password casuali"
    return 0
  fi
  info "Invio accetta il valore tra parentesi; le password non si vedono mentre scrivi."
  trap 'stty echo </dev/tty 2>/dev/null; exit 130' INT TERM
  # Postgres e torrent prima di ron1nos, che ne riprende le password.
  ordered=
  for s in postgres torrent; do
    case " $missing " in *" $s "*) ordered="$ordered $s" ;; esac
  done
  for s in $missing; do
    case $s in postgres | torrent) ;; *) ordered="$ordered $s" ;; esac
  done
  for s in $ordered; do ask_stack_env "$s"; done
  trap - INT TERM
}

# Reti, .env con password casuali coerenti fra stack e avvio di tutto:
# lo fa infra.sh (docs/specs/infra.md). SUDO_UID/SUDO_GID dicono a
# infra.sh di chi sono i file, come se lo lanciasse $ADMIN con sudo.
start_stacks() {
  step "Avvio degli stack"
  SUDO_UID=$ADMIN_UID SUDO_GID=$ADMIN_GID "$RON1N_DIR/infra.sh" up
}

summary() {
  step "Fatto"
  info "voci fatte: $SCELTE"
  if scelta stack; then summary_stack; fi
  documents_key_note
}

summary_stack() {
  proxy=$RON1N_DIR/infra/proxy
  dominio=$(env_get "$proxy/.env" DOMINIO)
  # I nomi dei siti dai matcher del Caddyfile (@nome host ...).
  hosts=$(sed -n 's/^[[:space:]]*@[a-z]* host \(.*\)$/\1/p' "$proxy/Caddyfile" |
    sed "s/{\$DOMINIO}/$dominio/g" | tr '\n' ' ')

  echo
  if [ -z "$(env_get "$RON1N_DIR/infra/tunnel/.env" TUNNEL_TOKEN)" ]; then
    echo "  Manca TUNNEL_TOKEN in infra/tunnel/.env: senza, i siti non si aprono."
    echo "  Passi in docs/server-setup.md (Accesso da fuori con Cloudflare)."
    echo
  fi
  echo "  Indirizzi, dietro Cloudflare Access:"
  for h in $hosts; do echo "    https://$h"; done
  echo
  echo "  Configurazione, nei .env degli stack (leggibili solo da $ADMIN e root):"
  for f in "$RON1N_DIR"/infra/*/.env; do
    [ -f "$f" ] && echo "    $f"
  done
  echo "  Dopo una modifica: cd $RON1N_DIR && ./infra.sh up (da $ADMIN, senza sudo)"
  echo
  echo "  Credenziali:"
  echo "    qBittorrent  $(env_get "$RON1N_DIR/infra/torrent/.env" QBT_USERNAME) / $(env_get "$RON1N_DIR/infra/torrent/.env" QBT_PASSWORD)"
  if grep -q '^AUTH_PASSWORD_HASH=' "$RON1N_DIR/infra/ron1nos/.env" 2>/dev/null; then
    echo "    ron1nOS      la password scelta"
  else
    echo "    ron1nOS      login spento: protetta solo da Cloudflare Access"
  fi
  echo "  Stato dei container: docker ps (dopo un nuovo login di $ADMIN, o con sudo)."
}

documents_key_note() {
  [ "${DOCUMENTS_KEY_NEW:-0}" = 1 ] || return 0
  echo
  echo "  Salva DOCUMENTS_KEY (in infra/ron1nos/.env) in un password manager:"
  echo "  senza, i documenti di ron1nOS non si leggono più."
}

main() {
  parse_args "$@"
  check_system
  find_user
  choose
  check_voci
  install_base
  if scelta aggiornamenti; then setup_updates; fi
  if scelta docker; then install_docker; fi
  if scelta gruppi; then setup_user; fi
  if scelta tailscale; then install_tailscale; fi
  if scelta ssh; then setup_ssh; fi
  if scelta repo; then clone_repo; fi
  if scelta env; then ask_envs; fi
  if scelta firewall; then setup_firewall; fi
  if scelta stack; then start_stacks; fi
  summary
}

# RON1N_BOOTSTRAP_LIB=1 carica solo le funzioni, per i test.
if [ "${RON1N_BOOTSTRAP_LIB:-0}" != 1 ]; then
  main "$@"
fi
