#!/bin/sh
# L'opposto di bootstrap.sh (SETUP-002): spegne gli stack e toglie, una
# voce alla volta, quello che il bootstrap ha messo sul server. Chiede cosa
# eliminare e, prima di cominciare, conferma il riepilogo.
#
#   sudo /opt/ron1n/scripts/cleanup.sh
#
# Senza terminale, o per non rispondere alle domande, le voci si scelgono
# con le opzioni e --yes salta la conferma:
#
#   --stacks     container, volumi (tutti i dati), immagini, reti e .env
#   --downloads  cartella dei download di qBittorrent
#   --docker     Docker Engine, con tutto quello che contiene
#   --firewall   ufw e le sue regole
#   --ssh        regole SSH di ron1n (tornano quelle di Debian)
#   --tailscale  Tailscale, il server esce dalla tailnet
#   --repo       la copia del repo sul server (questa cartella)
#   --all        tutte le voci
#   --yes        nessuna conferma
#
# Niente backup: i dati cancellati si perdono. Il repo su GitHub non si
# tocca. Restano sempre i pacchetti di base (curl, git, sudo, openssl,
# lm-sensors), gli aggiornamenti automatici e il gruppo sudo dell'utente.
set -eu

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
export DEBIAN_FRONTEND=noninteractive

ROOT=$(cd "$(dirname "$0")/.." && pwd)

ITEMS="stacks downloads docker firewall ssh tailscale repo"
YES=0
CHOSEN=
for arg in "$@"; do
  case $arg in
    --yes) YES=1 ;;
    --all) CHOSEN=$ITEMS ;;
    -h | --help)
      sed -n '2,24s/^# \{0,1\}//p' "$0"
      exit 0
      ;;
    *)
      item=${arg#--}
      case " $ITEMS " in
        *" $item "*) CHOSEN="$CHOSEN $item" ;;
        *)
          echo "opzione sconosciuta: $arg (vedi --help)" >&2
          exit 1
          ;;
      esac
      ;;
  esac
done

# Le funzioni di infra.sh: elenco e ordine degli stack, nomi dei progetti,
# messaggi.
# shellcheck disable=SC2034 # letto da infra.sh
INFRA_LIB=1
# shellcheck disable=SC1091
. "$ROOT/infra.sh"
# infra.sh ricava ROOT da $0, che qui è scripts/: si rimette quello giusto.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
INFRA=$ROOT/infra

[ "$(id -u)" -eq 0 ] || die "va eseguito da root: sudo $0"

DL=/srv/downloads
if [ -f "$INFRA/torrent/.env" ]; then
  d=$(env_get "$INFRA/torrent/.env" DOWNLOADS_DIR)
  DL=${d:-$DL}
fi

# Collegati via Tailscale? Togliere Tailscale chiude la connessione.
via_tailscale=0
case "${SSH_CONNECTION:-}" in
  100.*) via_tailscale=1 ;;
esac

chosen() {
  case " $CHOSEN " in *" $1 "*) return 0 ;; esac
  return 1
}

describe() {
  case $1 in
    stacks) echo "stack: container, volumi con tutti i dati, immagini, reti e .env" ;;
    downloads) echo "cartella dei download $DL" ;;
    docker) echo "Docker Engine, con immagini e volumi rimasti" ;;
    firewall) echo "firewall ufw e le sue regole" ;;
    ssh) echo "regole SSH di ron1n (tornano quelle di Debian)" ;;
    tailscale) echo "Tailscale, il server esce dalla tailnet" ;;
    repo) echo "copia del repo in $ROOT" ;;
  esac
}

# Una domanda per voce; senza risposta vale no.
ask() {
  echo "Cosa elimino? Rispondi s o n (invio = n)."
  for item in $ITEMS; do
    printf '  %s? [s/N] ' "$(describe "$item")"
    read -r answer || answer=
    case $answer in
      s | S | si | sì) CHOSEN="$CHOSEN $item" ;;
    esac
  done
}

confirm() {
  # Docker cancella anche i volumi, quindi gli stack vanno spenti prima.
  if chosen docker && ! chosen stacks; then
    CHOSEN="stacks $CHOSEN"
    info "con Docker vanno via anche gli stack: li aggiungo"
  fi
  [ -n "$CHOSEN" ] || die "nessuna voce scelta, non ho toccato niente"
  echo
  echo "Elimino:"
  for item in $ITEMS; do
    chosen "$item" && echo "  - $(describe "$item")"
  done
  if chosen tailscale && [ "$via_tailscale" = 1 ]; then
    echo "Sei collegato via Tailscale: la connessione cade alla fine."
  fi
  [ "$YES" = 1 ] && return 0
  printf 'Scrivi cancella per continuare: '
  read -r answer || answer=
  [ "$answer" = cancella ] || die "annullato, non ho toccato niente"
}

clean_stacks() {
  if ! command -v docker >/dev/null || ! docker info >/dev/null 2>&1; then
    step "Stack"
    info "Docker non c'è o non risponde, salto"
    rm -f "$INFRA"/*/.env
    return 0
  fi
  stacks=$(all_stacks)

  # Le immagini si leggono dai container prima di spegnerli.
  images=
  for s in $stacks; do
    images="$images $(containers "$s" '{{.Image}}' | tr '\n' ' ')"
  done

  # Spegnimento ordinato, come ./infra.sh down: prima Caddy, Postgres per
  # ultimo.
  cmd_down

  step "Dati degli stack"
  for s in $stacks; do
    p=$(project_name "$s")
    # Container rimasti, per esempio di uno stack senza .env.
    ids=$(containers "$s")
    # shellcheck disable=SC2086 # un id per parola
    [ -z "$ids" ] || docker rm -f $ids >/dev/null
    vols=$(docker volume ls -q --filter "label=com.docker.compose.project=$p")
    if [ -n "$vols" ]; then
      # shellcheck disable=SC2086 # un volume per parola
      docker volume rm $vols >/dev/null
      info "$s: volumi $(echo "$vols" | tr '\n' ' ')"
    fi
    if [ -f "$INFRA/$s/.env" ]; then
      rm -f "$INFRA/$s/.env"
      info "$s: .env cancellato"
    fi
  done

  # Override per Watchtower scritto dalle prime versioni di bootstrap.sh.
  override=$INFRA/updates/compose.override.yaml
  if [ -f "$override" ] && grep -q "Creato da scripts/bootstrap.sh" "$override"; then
    rm -f "$override"
    info "updates: compose.override.yaml cancellato"
  fi

  for img in $(echo "$images" | tr ' ' '\n' | sort -u); do
    if docker image rm "$img" >/dev/null 2>&1; then info "immagine $img"; fi
  done

  for net in $NETWORKS; do
    docker network inspect "$net" >/dev/null 2>&1 || continue
    docker network rm "$net" >/dev/null
    info "rete $net"
  done
}

clean_cert() {
  for crt in /root/ron1n-caddy-root.crt /home/*/ron1n-caddy-root.crt; do
    [ -f "$crt" ] || continue
    rm -f "$crt"
    info "$crt"
  done
}

clean_downloads() {
  step "Download"
  if [ -d "$DL" ]; then
    rm -rf "$DL"
    info "$DL cancellata"
  else
    info "$DL non c'è"
  fi
}

apt_purge() {
  pkgs=
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
  done
  [ -n "$pkgs" ] || return 0
  # shellcheck disable=SC2086 # un pacchetto per parola
  apt-get purge -y -q $pkgs </dev/null >/dev/null
  info "disinstallati:$pkgs"
}

remove_docker() {
  step "Docker"
  systemctl disable --now docker.service docker.socket containerd.service >/dev/null 2>&1 || true
  apt_purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker ||
    info "qualcosa in /var/lib/docker è ancora in uso: si cancella dopo un riavvio"
  rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc
  if getent group docker >/dev/null; then
    groupdel docker
    info "gruppo docker cancellato"
  fi
}

remove_firewall() {
  step "Firewall"
  if command -v ufw >/dev/null; then
    ufw --force disable >/dev/null
  fi
  apt_purge ufw
  # Il blocco DOCKER-USER in after.rules, se il purge ha lasciato il file.
  if [ -f /etc/ufw/after.rules ]; then
    sed -i '/^# BEGIN ron1n DOCKER-USER/,/^# END ron1n DOCKER-USER/d' /etc/ufw/after.rules
  fi
}

remove_ssh() {
  step "SSH"
  conf=/etc/ssh/sshd_config.d/10-ron1n.conf
  if [ ! -f "$conf" ]; then
    info "nessuna regola di ron1n"
    return 0
  fi
  rm -f "$conf"
  sshd -t && systemctl reload ssh
  info "tolte le regole di ron1n: valgono di nuovo quelle di Debian"
}

remove_repo() {
  step "Repo"
  # Lo script gira da qui: la shell ha già il file aperto, cancellarlo non
  # la ferma.
  rm -rf "$ROOT"
  info "$ROOT cancellato"
}

# Per ultimo, perché chiude le connessioni via Tailscale. Se la sessione è
# su Tailscale, gira staccato dal terminale, così finisce anche quando la
# connessione cade.
remove_tailscale() {
  step "Tailscale"
  if ! command -v tailscale >/dev/null; then
    info "non installato"
    return 0
  fi
  cmd='tailscale logout >/dev/null 2>&1 || true
systemctl disable --now tailscaled >/dev/null 2>&1 || true
apt-get purge -y -q tailscale </dev/null >/dev/null
rm -rf /var/lib/tailscale
rm -f /etc/apt/sources.list.d/tailscale.list /usr/share/keyrings/tailscale-archive-keyring.gpg'
  if [ "$via_tailscale" = 1 ]; then
    log=/var/log/ron1n-cleanup-tailscale.log
    setsid sh -c "$cmd" >"$log" 2>&1 </dev/null &
    info "lo tolgo adesso: la connessione cade. Log in $log"
  else
    sh -c "$cmd"
    info "server fuori dalla tailnet, Tailscale disinstallato"
  fi
}

if [ -z "$CHOSEN" ]; then
  [ -t 0 ] || die "senza terminale scegli le voci con le opzioni (vedi --help)"
  ask
fi
confirm

if chosen stacks; then
  clean_stacks
  clean_cert
fi
if chosen downloads; then clean_downloads; fi
if chosen docker; then remove_docker; fi
if chosen firewall; then remove_firewall; fi
if chosen ssh; then remove_ssh; fi
if chosen repo; then remove_repo; fi
step "Fatto"
if chosen repo || chosen docker; then
  info "Per rifare tutto: bootstrap.sh (docs/server-setup.md)."
else
  info "Per ripartire: ./infra.sh up, oppure bootstrap.sh per il sistema."
fi
# Per ultimo: chiude le connessioni via Tailscale.
if chosen tailscale; then remove_tailscale; fi
