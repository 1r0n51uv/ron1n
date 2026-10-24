#!/bin/sh
# Prepara l'account Cloudflare per il server (SETUP-010): tunnel con il suo
# instradamento, record DNS wildcard, Cloudflare Access con le due policy e
# il service token dell'app iOS, più l'eccezione per la source di SideStore
# (SETUP-011). Si può rilanciare: ogni oggetto si cerca
# per nome e si crea solo se manca, altrimenti si aggiorna.
#
#   scripts/cloudflare.sh [--dry-run] [--ruota]
#
#   --dry-run  legge e mostra cosa farebbe, senza cambiare niente
#   --ruota    cambia il secret del service token (quello vecchio smette
#              subito di valere)
#
# Credenziali in CF_ENV (default ~/.cf-home/.env, permessi 600):
#   CLOUDFLARE_API_TOKEN   token personalizzato, permessi in docs/server-setup.md
#   CLOUDFLARE_ACCOUNT_ID  Account ID
#   ACCESS_EMAIL           l'email che entra dal browser
# Scrive in CF_HOME (default ~/.cf-home) tunnel-token e ron1nos-ios.json,
# con permessi 600. Non stampa mai token né secret.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CF_HOME=${CF_HOME:-$HOME/.cf-home}
CF_ENV=${CF_ENV:-$CF_HOME/.env}
CF_API=${CF_API:-https://api.cloudflare.com/client/v4}

TUNNEL=ron1n
APP=ron1n
TOKEN_NAME=ron1nos-ios
SESSIONE=730h
# SETUP-011: source e IPA per SideStore, che non sa fare il login di Access.
APP_STORE="ron1n · SideStore"
POLICY_PUBBLICA="ron1n · pubblico"

info() { printf '    %s\n' "$*"; }
step() { printf '\033[1;31m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\033[1;31merrore:\033[0m %s\n' "$*" >&2
  exit 1
}

DRY=0
RUOTA=0
for arg in "$@"; do
  case $arg in
    --dry-run) DRY=1 ;;
    --ruota) RUOTA=1 ;;
    -h | --help)
      sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "opzione sconosciuta: $arg (vedi --help)" ;;
  esac
done

command -v curl >/dev/null || die "manca curl"
command -v jq >/dev/null || die "manca jq: sudo apt-get install jq"
[ -f "$CF_ENV" ] || die "manca $CF_ENV con CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID e ACCESS_EMAIL"
# shellcheck disable=SC1090
. "$CF_ENV"
: "${CLOUDFLARE_API_TOKEN:?manca CLOUDFLARE_API_TOKEN in $CF_ENV}"
: "${CLOUDFLARE_ACCOUNT_ID:?manca CLOUDFLARE_ACCOUNT_ID in $CF_ENV}"
: "${ACCESS_EMAIL:?manca ACCESS_EMAIL in $CF_ENV}"
ACC=/accounts/$CLOUDFLARE_ACCOUNT_ID

# Il dominio è quello di Caddy (infra/proxy/.env), come per il tunnel.
DOMINIO=
for f in "$ROOT/infra/proxy/.env" "$ROOT/infra/proxy/.env.example"; do
  [ -f "$f" ] || continue
  DOMINIO=$(sed -n 's/^DOMINIO=//p' "$f" | tail -n 1)
  [ -n "$DOMINIO" ] && break
done
[ -n "$DOMINIO" ] || die "manca DOMINIO in infra/proxy/.env"
# "ron1n · sev" per sev.amm.dev@gmail.com.
POLICY_EMAIL="ron1n · ${ACCESS_EMAIL%%[.@]*}"

umask 077
mkdir -p "$CF_HOME"

# api METODO PERCORSO [CORPO]: la risposta JSON su stdout. Esce se
# Cloudflare risponde con un errore, mostrandone il messaggio.
api() {
  out=$(curl -sS -X "$1" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    ${3:+--data "$3"} "$CF_API$2") || die "$1 $2: Cloudflare non risponde"
  if [ "$(printf '%s' "$out" | jq -r '.success // false')" != true ]; then
    die "$1 $2: $(printf '%s' "$out" | jq -r '[.errors[]?.message] | join("; ")' 2>/dev/null)"
  fi
  printf '%s' "$out"
}

# scrivi METODO PERCORSO CORPO: come api, ma con --dry-run lo dice e basta.
scrivi() {
  if [ "$DRY" = 1 ]; then
    info "farei: $1 $2" >&2
    printf '{"success":true,"result":{"id":"(nuovo)"}}'
  else
    api "$@"
  fi
}

# id NOME: l'id dell'oggetto con quel nome in un elenco su stdin.
id_per_nome() { jq -r --arg n "$1" '[.result[]? | select(.name == $n)][0].id // empty'; }

step "Tunnel $TUNNEL"
tunnel_id=$(api GET "$ACC/cfd_tunnel?is_deleted=false&name=$TUNNEL" | id_per_nome "$TUNNEL")
if [ -n "$tunnel_id" ]; then
  info "c'è già: $tunnel_id"
else
  tunnel_id=$(scrivi POST "$ACC/cfd_tunnel" \
    "$(jq -nc --arg n "$TUNNEL" '{name: $n, config_src: "cloudflare"}')" | jq -r .result.id)
  info "creato: $tunnel_id"
fi
# Tutto *.DOMINIO a Caddy, che smista per nome; il resto riceve 404.
scrivi PUT "$ACC/cfd_tunnel/$tunnel_id/configurations" "$(jq -nc --arg h "*.$DOMINIO" \
  '{config: {ingress: [{hostname: $h, service: "http://caddy:80"}, {service: "http_status:404"}]}}')" >/dev/null
info "instradamento: *.$DOMINIO → http://caddy:80"

step "DNS *.$DOMINIO"
zona=$(api GET "/zones?name=$DOMINIO" | jq -r '.result[0].id // empty')
[ -n "$zona" ] || die "il dominio $DOMINIO non è in questo account Cloudflare"
record=$(jq -nc --arg c "$tunnel_id.cfargotunnel.com" \
  '{type: "CNAME", name: "*", content: $c, proxied: true, comment: "Cloudflare Tunnel ron1n (SETUP-008)"}')
record_id=$(api GET "/zones/$zona/dns_records?type=CNAME&name=*.$DOMINIO" | jq -r '.result[0].id // empty')
if [ -n "$record_id" ]; then
  scrivi PUT "/zones/$zona/dns_records/$record_id" "$record" >/dev/null
  info "aggiornato: CNAME verso il tunnel, con proxy"
else
  scrivi POST "/zones/$zona/dns_records" "$record" >/dev/null
  info "creato: CNAME verso il tunnel, con proxy"
fi

step "Token del tunnel"
if [ "$DRY" = 1 ]; then
  info "lo salverei in $CF_HOME/tunnel-token"
else
  api GET "$ACC/cfd_tunnel/$tunnel_id/token" | jq -r .result >"$CF_HOME/tunnel-token"
  info "in $CF_HOME/tunnel-token"
fi

# policy NOME CORPO: crea o aggiorna la policy riusabile, stampa l'id.
policy() {
  pid=$(api GET "$ACC/access/policies" | id_per_nome "$1")
  if [ -n "$pid" ]; then
    scrivi PUT "$ACC/access/policies/$pid" "$2" >/dev/null
    info "policy \"$1\" aggiornata" >&2
  else
    pid=$(scrivi POST "$ACC/access/policies" "$2" | jq -r .result.id)
    info "policy \"$1\" creata" >&2
  fi
  echo "$pid"
}

step "Access: chi entra"
p_email=$(policy "$POLICY_EMAIL" "$(jq -nc --arg n "$POLICY_EMAIL" --arg e "$ACCESS_EMAIL" --arg s "$SESSIONE" \
  '{name: $n, decision: "allow", include: [{email: {email: $e}}], session_duration: $s}')")

json=$CF_HOME/$TOKEN_NAME.json
token_id=$(api GET "$ACC/access/service_tokens" | id_per_nome "$TOKEN_NAME")
if [ -z "$token_id" ]; then
  # Il secret si vede solo adesso: va subito nel file.
  risposta=$(scrivi POST "$ACC/access/service_tokens" \
    "$(jq -nc --arg n "$TOKEN_NAME" '{name: $n, duration: "8760h"}')")
  token_id=$(printf '%s' "$risposta" | jq -r .result.id)
  [ "$DRY" = 1 ] || printf '%s' "$risposta" | jq .result >"$json"
  info "service token $TOKEN_NAME creato, credenziali in $json"
elif [ "$RUOTA" = 1 ]; then
  risposta=$(scrivi POST "$ACC/access/service_tokens/$token_id/rotate" '{}')
  [ "$DRY" = 1 ] || printf '%s' "$risposta" | jq .result >"$json"
  info "secret di $TOKEN_NAME cambiato, il vecchio non vale più: credenziali in $json"
else
  info "service token $TOKEN_NAME c'è già"
  [ -f "$json" ] || info "manca $json: il secret non si rilegge, rilancia con --ruota"
fi
p_token=$(policy "$TOKEN_NAME" "$(jq -nc --arg n "$TOKEN_NAME" --arg t "$token_id" \
  '{name: $n, decision: "non_identity", include: [{service_token: {token_id: $t}}]}')")

step "Access: applicazione *.$DOMINIO"
corpo=$(jq -nc --arg n "$APP" --arg d "*.$DOMINIO" --arg s "$SESSIONE" --arg a "$p_email" --arg b "$p_token" \
  '{type: "self_hosted", name: $n, domain: $d, session_duration: $s, app_launcher_visible: false,
    policies: [{id: $a, precedence: 1}, {id: $b, precedence: 2}]}')
app_id=$(api GET "$ACC/access/apps" | id_per_nome "$APP")
if [ -n "$app_id" ]; then
  scrivi PUT "$ACC/access/apps/$app_id" "$corpo" >/dev/null
  info "aggiornata"
else
  scrivi POST "$ACC/access/apps" "$corpo" >/dev/null
  info "creata"
fi

# Un'applicazione con un percorso preciso vale prima di quella su
# *.DOMINIO: qui Access lascia passare tutti, solo per questa cartella e
# quello che contiene.
step "Access: eccezione per SideStore su ios.$DOMINIO/sidestore/"
p_pubblica=$(policy "$POLICY_PUBBLICA" "$(jq -nc --arg n "$POLICY_PUBBLICA" \
  '{name: $n, decision: "bypass", include: [{everyone: {}}]}')")
corpo=$(jq -nc --arg n "$APP_STORE" --arg d "ios.$DOMINIO/sidestore" --arg p "$p_pubblica" \
  '{type: "self_hosted", name: $n, domain: $d, app_launcher_visible: false,
    policies: [{id: $p, precedence: 1}]}')
store_id=$(api GET "$ACC/access/apps" | id_per_nome "$APP_STORE")
if [ -n "$store_id" ]; then
  scrivi PUT "$ACC/access/apps/$store_id" "$corpo" >/dev/null
  info "aggiornata"
else
  scrivi POST "$ACC/access/apps" "$corpo" >/dev/null
  info "creata"
fi

step "Fatto"
if [ "$DRY" = 1 ]; then
  info "prova: niente è cambiato"
else
  info "sul server: sudo sed -i \"s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\$(cat $CF_HOME/tunnel-token)|\" infra/tunnel/.env"
  info "poi: sudo ./infra.sh up tunnel"
fi
