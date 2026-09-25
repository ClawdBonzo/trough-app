#!/bin/zsh
# App Store screenshots for Trough (iPhone 6.9", 1320 × 2868), end to end, for one or more store locales:
#   1. builds the Debug app (DerivedData: $TROUGH_DERIVED, default build/shots — gitignored),
#   2. captures the raw screens on a pinned simulator in the locale's UI language (9:41, full battery),
#      on the seeded in-memory demo profile (-TRSeedDemo: nothing touches a real store),
#   3. has the app export its crisp floating assets (-TRExportAssets → Documents/StoreAssets) and pulls
#      them out of the app container,
#   4. composes fastlane/screenshots/<locale>/1_iphone69.png … 7_iphone69.png (Tools/make_store_screenshots.swift)
#      and a contact sheet at $WORK/contact-<locale>.png (kept OUT of the deliver folder: deliver uploads
#      every PNG it finds there).
#
#   Trough/Tools/make_store_screenshots.sh [--no-build] [--compose] [storeLocale …]     (default: en-US)
#     --no-build  reuse the last Debug build
#     --compose   skip the simulator: compose from the last captures and assets
#   ONLY_SHOTS="03-pk 06-bloodwork" recaptures just those shots (the others keep their last capture)
#   TROUGH_SIM_UDID=<udid>  pin a simulator; default: the "Trough Shots iPhone 17 Pro Max" device, created
#                           on first run (iPhone 17 Pro Max, else iPhone 16 Pro Max; newest iOS runtime).
#   TROUGH_DERIVED=<dir>    DerivedData path for the build (and the $TROUGH_DERIVED/store work dir).
#
# Only ever touches that one simulator; every simctl call runs under a timeout. Other simulators are left alone.
set -u
ROOT=${0:A:h:h}          # …/Trough (the folder with Trough.xcodeproj)
cd "$ROOT"
SIM_NAME="Trough Shots iPhone 17 Pro Max"
BUNDLE=app.trough.ios
DERIVED=${TROUGH_DERIVED:-build/shots}
APP=$DERIVED/Build/Products/Debug-iphonesimulator/Trough.app
WORK=$DERIVED/store
ICON=Trough/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

BUILD=1; CAPTURE=1
LOCALES=()
for arg in "$@"; do
  case $arg in
    --no-build) BUILD=0 ;;
    --compose) BUILD=0; CAPTURE=0 ;;
    *) LOCALES+=("$arg") ;;
  esac
done
(( ${#LOCALES} )) || LOCALES=(en-US)

# Runs a command, SIGKILLed after $1 seconds (simctl ignores SIGALRM when CoreSimulator is wedged).
timeout_kill() {
  local seconds=$1; shift
  "$@" &
  local pid=$!
  ( sleep $seconds; kill -9 $pid ) </dev/null >/dev/null 2>&1 &
  local watchdog=$!
  wait $pid; local rc=$?
  kill $watchdog 2>/dev/null
  return $rc
}
sim() { timeout_kill 120 xcrun simctl "$@"; }

# The pinned simulator: $TROUGH_SIM_UDID, else the dedicated device (created once).
UDID=${TROUGH_SIM_UDID:-}
if [[ -z $UDID ]]; then
  UDID=$(timeout_kill 120 xcrun simctl list devices | grep -F "$SIM_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
fi
if [[ -z $UDID ]]; then
  RUNTIME=$(timeout_kill 120 xcrun simctl list runtimes available | grep -E '^iOS ' | tail -1 | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/')
  for TYPE in com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max; do
    UDID=$(timeout_kill 300 xcrun simctl create "$SIM_NAME" "$TYPE" "$RUNTIME" 2>/dev/null) && break
  done
  [[ -n $UDID ]] || { echo "could not create the $SIM_NAME simulator" >&2; exit 1; }
  echo "created simulator $SIM_NAME ($UDID, $RUNTIME)"
fi
echo "simulator: $UDID"

# True when the middle of a screenshot is one flat colour (nothing drawn yet).
is_blank() {
  python3 - "$1" <<'PY' 2>/dev/null
import sys
try:
    from PIL import Image, ImageStat
except ImportError:
    sys.exit(1)
im = Image.open(sys.argv[1]).convert("L"); w, h = im.size
sys.exit(0 if ImageStat.Stat(im.crop((0, int(h * .2), w, int(h * .8)))).stddev[0] < 3 else 1)
PY
}

# Store locale → UI language and AppleLocale for the captures.
ui_language() {
  case $1 in
    en-US) echo "en en_US" ;; en-GB) echo "en-GB en_GB" ;; en-CA) echo "en-CA en_CA" ;; en-AU) echo "en-AU en_AU" ;;
    de-DE) echo "de de_DE" ;; fr-FR) echo "fr fr_FR" ;; es-ES) echo "es es_ES" ;; es-MX) echo "es-419 es_MX" ;;
    it) echo "it it_IT" ;; ja) echo "ja ja_JP" ;; ko) echo "ko ko_KR" ;; nl-NL) echo "nl nl_NL" ;; pl) echo "pl pl_PL" ;;
    pt-BR) echo "pt-BR pt_BR" ;; sv) echo "sv sv_SE" ;; *) echo "" ;;
  esac
}

if (( BUILD )); then
  echo "building…"
  timeout_kill 1800 xcodebuild build -project Trough.xcodeproj -scheme Trough -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath $DERIVED -quiet 2>&1 | grep -E "error:" && { echo "build failed" >&2; exit 1; }
fi

BASE_ARGS=(-TRSeedDemo -TRSkipOnboarding -TRScreenshotMode)
# The raw screens: file → extra launch arguments. (Slide 3 asks the dashboard to bring the PK card into
# view with -TRDashboardFocus pk; if the dashboard ignores it, the slide still shows the curve as the big
# floating pk-card asset.)
typeset -A SHOTS
SHOTS=(
  01-home         "-TRShowcase home"
  02-checkin      "-TRShowcase checkin -TRShowCompletion"
  03-pk           "-TRShowcase home -TRDashboardFocus pk"
  04-injections   "-TRShowcase injections"
  05-achievements "-TRShowcase achievements"
  06-bloodwork    "-TRShowcase bloodwork"
  07-privacy      "-TRShowcase more"
)
# Seconds to wait before the capture. Then the screen must hold still for a second (max ~12 s more),
# except the check-in celebration, whose confetti never settles on a fixed schedule.
typeset -A SETTLE
SETTLE=(01-home 6 02-checkin 5 03-pk 6 04-injections 5 05-achievements 6 06-bloodwork 5 07-privacy 4)
UNSTABLE=(02-checkin)

if (( CAPTURE )); then
  [[ -d $APP ]] || { echo "no Debug build at $APP" >&2; exit 1; }
  timeout_kill 1200 xcrun simctl bootstatus "$UDID" -b >/dev/null || { echo "simulator $UDID did not boot" >&2; exit 1; }
  sim install "$UDID" "$APP" || { echo "install failed" >&2; exit 1; }
  sim privacy "$UDID" grant notifications "$BUNDLE" >/dev/null 2>&1
  sim status_bar "$UDID" clear
  sim status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active \
    --wifiBars 3 --cellularBars 4 --dataNetwork 5g
  sim ui "$UDID" appearance dark >/dev/null 2>&1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for locale in $LOCALES; do
  read lang applelocale <<< "$(ui_language $locale)"
  [[ -n "$lang" ]] || { echo "unknown store locale $locale" >&2; continue; }
  RAW=$WORK/raw/$locale
  ASSETS=$WORK/assets/$locale
  if (( CAPTURE )); then
    mkdir -p $RAW $ASSETS
    LANG_ARGS=(-AppleLanguages "($lang)" -AppleLocale "$applelocale")
    # Warm-up: the first launch after an install or a boot is slow (fonts, SwiftData, RevenueCat).
    sim launch --terminate-running-process "$UDID" "$BUNDLE" $BASE_ARGS $LANG_ARGS >/dev/null; sleep 8
    for shot in ${(ko)SHOTS}; do
      [[ -n "${ONLY_SHOTS:-}" && " $ONLY_SHOTS " != *" $shot "* ]] && continue
      sim terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
      sim launch --terminate-running-process "$UDID" "$BUNDLE" $BASE_ARGS ${=SHOTS[$shot]} $LANG_ARGS >/dev/null \
        || { echo "launch failed: $shot" >&2; continue; }
      sleep ${SETTLE[$shot]}
      sim io "$UDID" screenshot "$TMP/prev.png" >/dev/null 2>&1
      # A blank frame (still seeding / still pushing) is stable too: wait it out, up to 40 s more.
      for i in {1..20}; do
        is_blank "$TMP/prev.png" || break
        sleep 2
        sim io "$UDID" screenshot "$TMP/prev.png" >/dev/null 2>&1
      done
      is_blank "$TMP/prev.png" && echo "  still blank: $locale $shot" >&2
      if (( ! ${UNSTABLE[(Ie)$shot]} )); then
        for i in {1..12}; do
          sleep 1
          sim io "$UDID" screenshot "$TMP/cur.png" >/dev/null 2>&1
          cmp -s "$TMP/prev.png" "$TMP/cur.png" && break
          mv "$TMP/cur.png" "$TMP/prev.png"
        done
      fi
      mv "$TMP/prev.png" "$RAW/$shot.png" && echo "  captured $locale $shot"
    done
    # Floating assets, rendered by the app at 3× (same demo profile, so the numbers match the screens).
    sim terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
    DATA=$(sim get_app_container "$UDID" "$BUNDLE" data)
    rm -rf "$DATA/Documents/StoreAssets"
    sim launch --terminate-running-process "$UDID" "$BUNDLE" $BASE_ARGS -TRShowcase home -TRExportAssets $LANG_ARGS >/dev/null
    for i in {1..60}; do [[ -f "$DATA/Documents/StoreAssets/done.txt" ]] && break; sleep 1; done
    [[ -f "$DATA/Documents/StoreAssets/done.txt" ]] || { echo "asset export timed out" >&2; exit 1; }
    rm -rf $ASSETS && mkdir -p $ASSETS
    cp "$DATA"/Documents/StoreAssets/* $ASSETS/
    echo "  exported $(ls $ASSETS | wc -l | tr -d ' ') assets"
    sim terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  fi
  mkdir -p $WORK
  swiftc -O -o $WORK/compose Tools/make_store_screenshots.swift 2>&1 | grep -E "error" && exit 1
  $WORK/compose --metadata fastlane/metadata --raw $RAW --assets $ASSETS --out fastlane/screenshots \
    --locale $locale --icon $ICON --contact $WORK/contact-$locale.png || exit 1
done
if (( CAPTURE )); then
  sim status_bar "$UDID" clear
fi
exit 0
