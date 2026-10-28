#!/bin/sh
# Comandi del builder iOS (IOSB-001), dentro il container ios-builder:
#
#   sdk            installa l'SDK iOS dall'unico .xip in /work
#   build [ref]    compila IOS_REPO al ref dato (default main) in un'IPA
#                  non firmata, in /work/builds; da main la pubblica anche
#                  nella source di SideStore (IOSB-003)
#   segui          resta acceso e compila main a ogni commit nuovo
#                  (IOSB-004), è il servizio ios-autobuild
#
# /work è IOS_DIR sull'host. Si lancia con
# docker compose -f infra/ios/compose.yaml run --rm ios-builder <comando>.
set -eu

WORK=${WORK:-/work}
BUILDS=$WORK/builds
SRC=$WORK/src
# La source di SideStore e le sue IPA: l'unica parte della pagina fuori da
# Cloudflare Access (SETUP-011), perché SideStore non sa fare il login.
STORE=$BUILDS/sidestore
KEEP=5
IOS_URL=${IOS_URL:-https://ios.ron1n.space}
INTERVALLO=${IOS_INTERVALLO:-300}
# L'icona dell'app nella source: SideStore rifiuta una source senza iconURL.
ICON=${IOS_ICON:-/usr/local/share/ios-build/icon.png}

info() { printf '    %s\n' "$*"; }
step() { printf '\033[1;31m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\033[1;31merrore:\033[0m %s\n' "$*" >&2
  exit 1
}

# Swift prende la home da /etc/passwd, non da HOME: se le due non
# coincidono l'SDK finirebbe fuori da /work e sparirebbe con il container.
check_home() {
  mkdir -p "$HOME"
  passwd_home=$(getent passwd "$(id -u)" | cut -d: -f6) || passwd_home=
  if [ -n "$passwd_home" ] && [ "$passwd_home" != "$HOME" ]; then
    die "l'utente $(id -u) ha la home in $passwd_home, non in $HOME: usa PUID=1000 o ricostruisci l'immagine"
  fi
}

usage() {
  cat <<'USAGE'
Uso: ios-builder <comando>

  sdk           installa l'SDK iOS dall'unico .xip in IOS_DIR
  build [ref]   compila IOS_REPO al ref dato (default main) in IOS_DIR/builds
  segui         compila main a ogni commit nuovo, ogni IOS_INTERVALLO secondi
USAGE
}

has_sdk() {
  status=$(xtool sdk status) || die "xtool non parte: l'errore è sopra"
  case $status in *"is installed"*) return 0 ;; esac
  return 1
}

cmd_sdk() {
  step "SDK iOS"
  if has_sdk; then
    info "già installato: per rifarlo, xtool sdk remove e poi di nuovo sdk"
    return 0
  fi
  set -- "$WORK"/*.xip
  [ -f "$1" ] || die "nessun .xip in IOS_DIR: scarica Xcode da developer.apple.com/download/all e copialo lì (infra/ios/README.md)"
  [ $# -eq 1 ] || die "più di un .xip in IOS_DIR: lascia solo quello da usare"
  info "da $(basename "$1"), ci vuole qualche minuto"
  xtool sdk install "$1"
  info "fatto: ora puoi cancellare $(basename "$1") da IOS_DIR"
}

# git clone con il token in un header, solo per questo comando: non resta
# nella configurazione dei sorgenti clonati.
git_auth() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    basic=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)
    git -c "http.extraHeader=Authorization: Basic $basic" "$@"
  else
    git "$@"
  fi
}

# Le build più vecchie oltre le ultime KEEP di $2 nella cartella $1, tranne
# la copia $2.ipa.
prune() {
  # shellcheck disable=SC2012 # nomi generati da noi, senza spazi
  ls -t "$1/$2"-*.ipa 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    rm -f "$old"
    info "tolta $(basename "$old")"
  done
}

# set_plist FILE CHIAVE VALORE: cambia la stringa che segue <key>CHIAVE</key>
# in un Info.plist XML, o la aggiunge in fondo al dict.
set_plist() {
  awk -v k="<key>$2</key>" -v v="$3" '
    found == 1 && /<string>/ { sub(/<string>[^<]*<\/string>/, "<string>" v "</string>"); found = 2 }
    index($0, k) { found = 1 }
    /^<\/dict>/ && found == 0 { print "\t" k; print "\t<string>" v "</string>"; found = 2 }
    { print }
  ' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# get_plist FILE CHIAVE: la stringa che segue <key>CHIAVE</key>.
get_plist() {
  awk -v k="<key>$2</key>" '
    found && /<string>/ { gsub(/.*<string>|<\/string>.*/, ""); print; exit }
    index($0, k) { found = 1 }
  ' "$1"
}

# versiona PLIST N: il numero di build è N, il numero di commit di main, e
# la versione diventa major.minor.N. Così sale a ogni commit e SideStore
# vede l'aggiornamento (IOSB-003).
versiona() {
  base=$(get_plist "$1" CFBundleShortVersionString)
  major=${base%%.*}
  rest=${base#*.}
  minor=${rest%%.*}
  [ "$rest" != "$base" ] || minor=0
  VERSIONE=${major:-0}.${minor:-0}.$2
  set_plist "$1" CFBundleShortVersionString "$VERSIONE"
  set_plist "$1" CFBundleVersion "$2"
}

# json_str TESTO: TESTO tra virgolette, con \, ", tab e a capo protetti.
json_str() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' |
    awk 'NR > 1 { printf "%s", "\\n" } { printf "%s", $0 }')"
}

# note_versione VERSIONE [DA]: le novità della versione per SideStore
# (IOSB-005). Prima la sezione `## VERSIONE` del CHANGELOG.md dei sorgenti;
# se non c'è, i titoli dei commit dopo DA, l'ultimo pubblicato (al massimo
# 20), o il solo ultimo commit. Si lancia dentro i sorgenti.
note_versione() {
  if [ -f CHANGELOG.md ]; then
    note=$(awk -v v="$1" '
      /^## / { if (dentro) exit; if ($2 == v) { dentro = 1; next } }
      dentro && NF { print }
    ' CHANGELOG.md)
    if [ -n "$note" ]; then
      printf '%s\n' "$note"
      return
    fi
  fi
  if [ -n "${2:-}" ] && git cat-file -e "$2^{commit}" 2>/dev/null; then
    git log --format='- %s' --max-count=20 "$2..HEAD"
  else
    git log --format='- %s' -1
  fi
}

# pubblica IPA APP BUNDLE VERSIONE BUILD SHA [NOTE]: copia l'IPA in STORE
# e riscrive source.json nel formato delle source di AltStore e SideStore,
# con la sola ultima versione (IOSB-003) e le sue novità (IOSB-005).
pubblica() {
  mkdir -p "$STORE"
  nome=$2-$6.ipa
  cp "$1" "$STORE/$nome.tmp"
  mv "$STORE/$nome.tmp" "$STORE/$nome"
  size=$(wc -c <"$STORE/$nome" | tr -d ' ')
  data=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  url=$IOS_URL/sidestore/$nome
  icona=$IOS_URL/sidestore/icon.png
  [ -f "$ICON" ] && cp "$ICON" "$STORE/icon.png"
  cat >"$STORE/source.json.tmp" <<JSON
{
  "name": "ron1n",
  "identifier": "space.ron1n.ios",
  "sourceURL": $(json_str "$IOS_URL/sidestore/source.json"),
  "iconURL": $(json_str "$icona"),
  "apps": [
    {
      "name": $(json_str "$2"),
      "bundleIdentifier": $(json_str "$3"),
      "developerName": "ron1n",
      "localizedDescription": "App di ron1n compilata sul server di casa.",
      "iconURL": $(json_str "$icona"),
      "version": $(json_str "$4"),
      "versionDate": "$data",
      "downloadURL": $(json_str "$url"),
      "size": $size,
      "versions": [
        {
          "version": $(json_str "$4"),
          "buildVersion": $(json_str "$5"),
          "date": "$data",
          "localizedDescription": $(json_str "${7:-Commit $6}"),
          "downloadURL": $(json_str "$url"),
          "size": $size
        }
      ]
    }
  ],
  "news": []
}
JSON
  mv "$STORE/source.json.tmp" "$STORE/source.json"
  printf '%s\n' "$6" >"$STORE/.commit"
  prune "$STORE" "$2"
}

cmd_build() {
  ref=${1:-main}
  [ -n "${IOS_REPO:-}" ] || die "manca IOS_REPO in infra/ios/.env"
  has_sdk || die "manca l'SDK iOS: copia Xcode.xip in IOS_DIR e lancia prima sdk"
  # Una build alla volta: ios-autobuild e una build a mano usano gli stessi
  # sorgenti in /work/src.
  exec 9>"$WORK/.build.lock"
  if ! flock -n 9; then
    info "c'è già una build in corso, aspetto"
    flock 9
  fi

  step "Sorgenti"
  rm -rf "$SRC"
  info "$IOS_REPO @ $ref"
  # Clone completo: il numero di build è il numero di commit.
  git_auth clone --quiet "$IOS_REPO" "$SRC" ||
    die "clone fallito: controlla IOS_REPO e, per un repo privato, GITHUB_TOKEN"
  cd "$SRC"
  git checkout --quiet "$ref" 2>/dev/null || die "ref sconosciuto: $ref"
  sha=$(git rev-parse --short=7 HEAD)
  n=$(git rev-list --count HEAD)
  plist=$(sed -n 's/^infoPath: *//p' xtool.yml 2>/dev/null)
  plist=${plist:-Info.plist}
  bundle=$(sed -n 's/^bundleID: *//p' xtool.yml 2>/dev/null)
  if [ -f "$plist" ]; then
    versiona "$plist" "$n"
    info "versione $VERSIONE (build $n)"
  else
    VERSIONE=
    info "manca $plist: versione lasciata a xtool"
  fi

  step "Build"
  xtool dev build --ipa --configuration release ||
    die "build fallita: l'errore è sopra"
  set -- xtool/*.ipa
  [ -f "$1" ] || die "xtool non ha prodotto un'IPA in xtool/"
  app=$(basename "$1" .ipa)

  step "IPA"
  mkdir -p "$BUILDS"
  cp "$1" "$BUILDS/$app-$sha.ipa"
  cp "$1" "$BUILDS/$app.ipa.tmp"
  mv "$BUILDS/$app.ipa.tmp" "$BUILDS/$app.ipa"
  prune "$BUILDS" "$app"
  info "$app-$sha.ipa, anche come $app.ipa"
  info "dal telefono: $IOS_URL/$app.ipa, poi Apri con SideStore"

  # Solo main va nella source: un branch di prova non diventa un update.
  if [ "$ref" = main ] && [ -n "$VERSIONE" ] && [ -n "$bundle" ]; then
    step "Source di SideStore"
    prima=$(cat "$STORE/.commit" 2>/dev/null) || prima=
    note=$(note_versione "$VERSIONE" "$prima")
    pubblica "$1" "$app" "$bundle" "$VERSIONE" "$n" "$sha" "$note"
    info "$IOS_URL/sidestore/source.json, versione $VERSIONE"
  fi
}

# L'ultimo commit di main su GitHub, abbreviato come in build.
remote_main() {
  git_auth ls-remote "$IOS_REPO" refs/heads/main 2>/dev/null | cut -c1-7
}

# Compila main ogni volta che cambia (IOSB-004). Una build fallita non si
# ritenta finché non arriva un commit nuovo.
cmd_segui() {
  [ -n "${IOS_REPO:-}" ] || die "manca IOS_REPO in infra/ios/.env"
  info "controllo main di $IOS_REPO ogni $INTERVALLO s"
  while :; do
    sha=$(remote_main) || sha=
    fatto=$(cat "$STORE/.commit" 2>/dev/null) || fatto=
    fallito=$(cat "$BUILDS/.fallito" 2>/dev/null) || fallito=
    if [ -z "$sha" ]; then
      info "$(date '+%F %T') GitHub non risponde, riprovo"
    elif [ "$sha" != "$fatto" ] && [ "$sha" != "$fallito" ]; then
      if ! (has_sdk); then
        info "$(date '+%F %T') manca l'SDK iOS: lancia sdk (infra/ios/README.md)"
      elif (cmd_build main); then
        rm -f "$BUILDS/.fallito"
      else
        printf '%s\n' "$sha" >"$BUILDS/.fallito"
        info "$(date '+%F %T') build di $sha fallita: riprovo al prossimo commit"
      fi
    fi
    sleep "$INTERVALLO"
  done
}

main() {
  [ $# -gt 0 ] || {
    usage
    exit 1
  }
  cmd=$1
  shift
  case $cmd in -h | --help | help) ;; *) check_home ;; esac
  case $cmd in
    sdk) cmd_sdk ;;
    build) cmd_build "$@" ;;
    segui) cmd_segui ;;
    -h | --help | help) usage ;;
    *)
      usage >&2
      die "comando sconosciuto: $cmd"
      ;;
  esac
}

# Con IOS_BUILD_LIB=1 si caricano solo le funzioni, per i test.
[ "${IOS_BUILD_LIB:-}" = 1 ] || main "$@"
