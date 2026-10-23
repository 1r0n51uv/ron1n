#!/bin/sh
# Comandi del builder iOS (IOSB-001), dentro il container ios-builder:
#
#   sdk            installa l'SDK iOS dall'unico .xip in /work
#   build [ref]    compila IOS_REPO al ref dato (default main) in un'IPA
#                  non firmata, in /work/builds
#
# /work è IOS_DIR sull'host. Si lancia con
# docker compose -f infra/ios/compose.yaml run --rm ios-builder <comando>.
set -eu

WORK=/work
BUILDS=$WORK/builds
SRC=$WORK/src
KEEP=5
mkdir -p "$HOME"

info() { printf '    %s\n' "$*"; }
step() { printf '\033[1;31m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\033[1;31merrore:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Uso: ios-builder <comando>

  sdk           installa l'SDK iOS dall'unico .xip in IOS_DIR
  build [ref]   compila IOS_REPO al ref dato (default main) in IOS_DIR/builds
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

# Le build più vecchie oltre le ultime KEEP di $1, tranne la copia $1.ipa.
prune() {
  # shellcheck disable=SC2012 # nomi generati da noi, senza spazi
  ls -t "$BUILDS/$1"-*.ipa 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    rm -f "$old"
    info "tolta $(basename "$old")"
  done
}

cmd_build() {
  ref=${1:-main}
  [ -n "${IOS_REPO:-}" ] || die "manca IOS_REPO in infra/ios/.env"
  has_sdk || die "manca l'SDK iOS: copia Xcode.xip in IOS_DIR e lancia prima sdk"

  step "Sorgenti"
  rm -rf "$SRC"
  info "$IOS_REPO @ $ref"
  git_auth clone --quiet --depth 1 --branch "$ref" "$IOS_REPO" "$SRC" 2>/dev/null ||
    git_auth clone --quiet "$IOS_REPO" "$SRC" ||
    die "clone fallito: controlla IOS_REPO e, per un repo privato, GITHUB_TOKEN"
  cd "$SRC"
  git checkout --quiet "$ref" 2>/dev/null || die "ref sconosciuto: $ref"
  sha=$(git rev-parse --short HEAD)

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
  prune "$app"
  info "$app-$sha.ipa, anche come $app.ipa"
  info "dal telefono: https://ios.ron1n.home/$app.ipa, poi Apri con SideStore"
}

main() {
  [ $# -gt 0 ] || {
    usage
    exit 1
  }
  cmd=$1
  shift
  case $cmd in
    sdk) cmd_sdk ;;
    build) cmd_build "$@" ;;
    -h | --help | help) usage ;;
    *)
      usage >&2
      die "comando sconosciuto: $cmd"
      ;;
  esac
}

main "$@"
