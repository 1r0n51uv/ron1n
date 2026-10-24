#!/bin/sh
# Test delle parti del builder iOS che non chiedono xtool (IOSB-003): numero
# di versione nell'Info.plist, source.json di SideStore e pulizia delle IPA.
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

printf 'png finto' >"$tmp/icon.png"
export WORK="$tmp/work" IOS_URL=https://ios.esempio.it IOS_ICON="$tmp/icon.png" IOS_BUILD_LIB=1
# shellcheck source=/dev/null
. "$ROOT/infra/ios/builder/ios-build.sh"

cat >"$tmp/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>6</string>
</dict>
</plist>
PLIST
versiona "$tmp/Info.plist" 19
check "versione major.minor.commit" test "$VERSIONE" = 0.1.19
check "versione nel plist" test "$(get_plist "$tmp/Info.plist" CFBundleShortVersionString)" = 0.1.19
check "build nel plist" test "$(get_plist "$tmp/Info.plist" CFBundleVersion)" = 19
check "plist senza righe in più" test "$(grep -c '<key>' "$tmp/Info.plist")" = 2

# Senza CFBundleVersion la chiave si aggiunge.
printf '<plist>\n<dict>\n\t<key>CFBundleShortVersionString</key>\n\t<string>2</string>\n</dict>\n</plist>\n' >"$tmp/Corto.plist"
versiona "$tmp/Corto.plist" 7
check "versione corta completata" test "$VERSIONE" = 2.0.7
check "build aggiunta" test "$(get_plist "$tmp/Corto.plist" CFBundleVersion)" = 7

# La source di SideStore.
printf 'ipa finta' >"$tmp/app.ipa"
pubblica "$tmp/app.ipa" Ron1nOS home.ron1n.ios 0.1.19 19 abc1234 >/dev/null
src=$WORK/builds/sidestore/source.json
check "source.json valido" sh -c "jq -e . '$src' >/dev/null"
check "IPA nella cartella pubblica" test -f "$WORK/builds/sidestore/Ron1nOS-abc1234.ipa"
check "url della source" test "$(jq -r .sourceURL "$src")" = https://ios.esempio.it/sidestore/source.json
check "bundle id" test "$(jq -r '.apps[0].bundleIdentifier' "$src")" = home.ron1n.ios
check "versione e build" test "$(jq -r '.apps[0].versions[0] | "\(.version) \(.buildVersion)"' "$src")" = "0.1.19 19"
check "url dell'IPA" test "$(jq -r '.apps[0].versions[0].downloadURL' "$src")" = https://ios.esempio.it/sidestore/Ron1nOS-abc1234.ipa
check "icona dell'app" test "$(jq -r '.apps[0].iconURL' "$src")" = https://ios.esempio.it/sidestore/icon.png
check "icona della source" test "$(jq -r .iconURL "$src")" = https://ios.esempio.it/sidestore/icon.png
check "icona nella cartella pubblica" test -f "$WORK/builds/sidestore/icon.png"
check "dimensione" test "$(jq -r '.apps[0].versions[0].size' "$src")" = 9
check "campi per le versioni vecchie di SideStore" test "$(jq -r '.apps[0].version' "$src")" = 0.1.19
check "commit pubblicato" test "$(cat "$WORK/builds/sidestore/.commit")" = abc1234

# Restano le ultime KEEP IPA.
i=0
while [ $i -lt 7 ]; do
  pubblica "$tmp/app.ipa" Ron1nOS home.ron1n.ios "0.1.$i" "$i" "sha$i" >/dev/null
  touch -d "@$((1700000000 + i))" "$WORK/builds/sidestore/Ron1nOS-sha$i.ipa"
  i=$((i + 1))
done
prune "$WORK/builds/sidestore" Ron1nOS >/dev/null
check "ultime $KEEP IPA" test "$(find "$WORK/builds/sidestore" -name 'Ron1nOS-*.ipa' | wc -l)" = "$KEEP"
check "tenuta la più recente" test -f "$WORK/builds/sidestore/Ron1nOS-sha6.ipa"
check "source sull'ultima" test "$(jq -r '.apps[0].version' "$src")" = 0.1.6

check "testo con virgolette in JSON" test "$(json_str 'a"b\c')" = '"a\"b\\c"'

[ "$fails" = 0 ] || {
  echo "$fails test falliti"
  exit 1
}
echo "tutti i test passati"
