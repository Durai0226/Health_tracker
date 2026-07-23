#!/usr/bin/env bash
# One-time: generate a release/upload keystore for DailyMinder, then print the
# SHA-1 to register in Firebase. You choose + safely store the passwords.
#
#   bash android/make_release_keystore.sh [output.jks]
#
# Default output is ~/keystores/dlyminder-upload.jks (OUTSIDE the repo, on purpose).
set -euo pipefail

OUT="${1:-$HOME/keystores/dlyminder-upload.jks}"
ALIAS="upload"

# Find a working keytool (PATH, then a JDK).
find_keytool() {
  if command -v keytool >/dev/null 2>&1; then echo "keytool"; return; fi
  local jh; jh="$(/usr/libexec/java_home 2>/dev/null || true)"
  for c in \
    "${jh:+$jh/bin/keytool}" \
    "$HOME/android-sdk/jdk/Contents/Home/bin/keytool" \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return; }
  done
  echo ""
}
KT="$(find_keytool)"
if [ -z "$KT" ]; then
  echo "ERROR: no 'keytool' (JDK) found. Install a JDK or run from a shell where 'keytool' is on PATH." >&2
  exit 1
fi

if [ -e "$OUT" ]; then
  echo "Refusing to overwrite existing keystore: $OUT" >&2
  echo "(A release keystore must never be regenerated once used to publish.)" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
echo "Generating release keystore at: $OUT"
echo "You'll be prompted for a store password, a key password, and your name/org."
echo
"$KT" -genkeypair -v \
  -keystore "$OUT" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$ALIAS"

echo
echo "================================================================"
echo "Keystore created: $OUT   (alias: $ALIAS)"
echo
echo "Its SHA-1 (register this in Firebase -> project settings ->"
echo "Android app com.dlyminder.app -> Add fingerprint):"
"$KT" -list -v -keystore "$OUT" -alias "$ALIAS" | grep -iE "SHA1:|SHA256:" || true
echo
echo "Next:"
echo "  1) cp android/key.properties.example android/key.properties"
echo "     and set storeFile=$OUT, keyAlias=$ALIAS, and your passwords."
echo "  2) Register the SHA-1 above in Firebase, re-download google-services.json"
echo "     into android/app/, then: flutter build appbundle --release"
echo "  3) For Play: also register the Play App Signing SHA-1 (Play Console"
echo "     -> Setup -> App signing) in Firebase."
echo "================================================================"
