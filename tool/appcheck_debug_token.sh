#!/usr/bin/env bash
# Print this device's Firebase App Check DEBUG token.
#
# Why this exists: the debug secret is generated and logged by the *native*
# Firebase SDK, so Dart can't read it and the app can't display it. It has to be
# scraped from logcat — and `adb` is not on PATH on this machine (it lives in
# ~/android-sdk/platform-tools), which makes the copy-pasted command from the
# Firebase docs fail with "command not found".
#
# Register the printed token at:
#   Firebase console -> Build -> App Check -> Apps -> com.dlyminder.app
#     -> (kebab menu) -> Manage debug tokens -> Add
#
# Without it, an App Check-enforced project rejects Firestore, Auth AND Gemini
# for this build — cloud sync and Smart answers both go quiet.

set -uo pipefail

PKG="com.dlyminder.app"
TIMEOUT_SECS="${TIMEOUT_SECS:-45}"

# ---- locate adb -------------------------------------------------------------
ADB=""
for candidate in \
  "$HOME/android-sdk/platform-tools/adb" \
  "$HOME/Library/Android/sdk/platform-tools/adb" \
  "$(command -v adb 2>/dev/null || true)"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then ADB="$candidate"; break; fi
done

if [ -z "$ADB" ]; then
  echo "✗ adb not found. Install Android platform-tools, or set ADB=/path/to/adb." >&2
  exit 1
fi
echo "• adb: $ADB"

# ---- require exactly one device ---------------------------------------------
DEVICES="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')"
COUNT="$(printf '%s\n' "$DEVICES" | grep -c . || true)"

if [ "$COUNT" -eq 0 ]; then
  cat >&2 <<'EOF'
✗ No device connected.

  Plug in your phone and enable USB debugging
  (Settings -> About phone -> tap "Build number" 7x -> Developer options ->
   USB debugging), then accept the "Allow USB debugging?" prompt.

  Check with:  ~/android-sdk/platform-tools/adb devices
EOF
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  echo "✗ More than one device attached. Unplug the others:" >&2
  printf '    %s\n' $DEVICES >&2
  exit 1
fi
echo "• device: $(printf '%s' "$DEVICES")"

# ---- app must be installed --------------------------------------------------
if ! "$ADB" shell pm list packages 2>/dev/null | grep -q "$PKG"; then
  cat >&2 <<EOF
✗ $PKG is not installed on the device.

  Install the testable build first:
    $ADB install -r ~/Downloads/DlyMinder-1.0.0-TESTABLE-appcheck-debug-20260803.apk
EOF
  exit 1
fi

# ---- capture the token ------------------------------------------------------
# The secret is logged once, at App Check initialisation. So clear the buffer,
# force-stop the app, relaunch it, and read from a clean slate — otherwise the
# line has already scrolled past and nothing ever appears.
echo "• clearing log buffer and restarting the app…"
"$ADB" logcat -c >/dev/null 2>&1 || true
"$ADB" shell am force-stop "$PKG" >/dev/null 2>&1 || true
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo "• watching logcat for up to ${TIMEOUT_SECS}s…"
echo ""

TOKEN=""
UUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# -m1 makes grep exit at the first match, which closes the logcat pipe.
LINE="$(
  "$ADB" logcat -v brief 2>/dev/null \
    | grep -m1 -iE "DebugAppCheckProvider|debug secret|appcheck.*debug" &
  WATCHER=$!
  ( sleep "$TIMEOUT_SECS"; kill "$WATCHER" 2>/dev/null ) >/dev/null 2>&1 &
  wait "$WATCHER" 2>/dev/null
)"

if [ -n "${LINE:-}" ]; then
  TOKEN="$(printf '%s' "$LINE" | grep -oE "$UUID_RE" | head -1)"
fi

if [ -z "$TOKEN" ]; then
  cat >&2 <<'EOF'
✗ No debug token seen.

  Most likely causes, in order:
   1. The build is NOT using the debug provider. A plain --release build selects
      Play Integrity and never logs a debug secret. Rebuild with:
        flutter build apk --release --dart-define=APPCHECK_DEBUG=true
   2. A token was already generated and registered on a previous run — the line
      is only logged when the secret is first created. To force a new one:
        adb shell pm clear com.dlyminder.app     (wipes app data!)
   3. The app didn't actually launch. Open it by hand, then re-run this script.

  Raw search, if you want to look yourself:
    ~/android-sdk/platform-tools/adb logcat | grep -i appcheck
EOF
  exit 1
fi

echo "════════════════════════════════════════════════════════════"
echo "  App Check debug token:"
echo ""
echo "      $TOKEN"
echo ""
echo "  Register it here:"
echo "    console.firebase.google.com -> Build -> App Check -> Apps"
echo "    -> $PKG -> ⋮ -> Manage debug tokens -> Add"
echo "════════════════════════════════════════════════════════════"

# Copy to the clipboard so it can't be mis-transcribed.
if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$TOKEN" | pbcopy && echo "  (copied to clipboard)"
fi
