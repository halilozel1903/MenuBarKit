#!/usr/bin/env bash
# Captures README screenshots of the macOS example app.
# Usage: scripts/screenshots.sh <Scheme> <scene> [<scene> ...]
# Writes docs/screenshots/<scene>.png, for example panel.png, and fails instead of saving a blank or broken capture.
#
# A real menu bar window cannot be opened reliably on a CI runner, so the app shows each scene in a
# regular window of a fixed size when launched with `-screenshot <scene>`.
#
# 1. Preferred: `screencapture -l <window id>` of the app's borderless window, with the id looked up by
#    scripts/window-id.swift (CGWindowListCopyWindowInfo, filtered by the app's process id).
# 2. Fallback: `-render-screenshot <file>` makes the app draw that window's content into a PNG itself
#    (NSView.cacheDisplay at 2x) and quit. It needs no Screen Recording permission, but it cannot
#    draw tab views and grouped forms.
set -euo pipefail

SCHEME="$1"; shift
OUT="docs/screenshots"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

MIN_BYTES=20000   # a blank 2x window compresses to a few KB
MIN_WIDTH=600     # pixels; every scene is at least 440 points wide

xcodebuild build \
  -project "Example/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= | tail -n 5

APP="$(find build/Build/Products -maxdepth 2 -name "$SCHEME.app" | head -n 1)"
BIN="$APP/Contents/MacOS/$SCHEME"
if [ -z "$APP" ] || [ ! -x "$BIN" ]; then
  echo "Could not find $SCHEME.app in build/Build/Products" >&2
  exit 1
fi

# valid_capture <file> <previous capture or empty>
# Rejects missing, tiny or narrow PNGs, and a capture identical to the previous scene.
valid_capture() {
  local file="$1" previous="$2" width
  [ -s "$file" ] || return 1
  [ "$(wc -c < "$file" | tr -d ' ')" -gt "$MIN_BYTES" ] || return 1
  width="$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
  [ -n "$width" ] && [ "$width" -ge "$MIN_WIDTH" ] || return 1
  if [ -n "$previous" ] && cmp -s "$file" "$previous"; then
    return 1
  fi
  return 0
}

# wait_for_exit <pid> <seconds>: waits for the process to quit, kills it after the timeout.
# Returns the process's exit status, or 124 on a timeout.
wait_for_exit() {
  local pid="$1" limit="$2" waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

# The app forces the light appearance itself; -ApplePersistenceIgnoreState keeps macOS from
# restoring windows of an earlier run.

# render <scene> <file>: path 1, the app renders its own window.
render() {
  local scene="$1" file="$2" pid status=0
  "$BIN" -screenshot "$scene" -render-screenshot "$file" -ApplePersistenceIgnoreState YES > "$TMP/$scene.log" 2>&1 &
  pid=$!
  wait_for_exit "$pid" 45 || status=$?
  cat "$TMP/$scene.log"
  return "$status"
}

# capture_window <scene> <file>: path 2, screencapture of the app's window by its window id.
capture_window() {
  local scene="$1" file="$2" pid id
  "$BIN" -screenshot "$scene" -ApplePersistenceIgnoreState YES > "$TMP/$scene-window.log" 2>&1 &
  pid=$!
  sleep 8
  id="$(swift scripts/window-id.swift "$pid" 2>/dev/null || true)"
  if [ -n "$id" ]; then
    screencapture -x -o -l "$id" "$file" || true
  else
    echo "No window found for $scene"
  fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

previous=""
for scene in "$@"; do
  capture="$TMP/$scene.png"
  ok=0
  # screencapture draws exactly what is on screen, including tab views and forms that
  # cacheDisplay leaves empty, so it goes first; the app's own renderer is the fallback.
  for attempt in 1 2; do
    rm -f "$capture"
    capture_window "$scene" "$capture"
    if valid_capture "$capture" "$previous"; then
      ok=1
      break
    fi
    echo "screencapture of $scene failed or was blank (attempt $attempt)"
  done
  if [ "$ok" -ne 1 ]; then
    echo "Falling back to the app's own renderer for $scene"
    rm -f "$capture"
    if render "$scene" "$capture" && valid_capture "$capture" "$previous"; then
      ok=1
    fi
  fi
  if [ "$ok" -ne 1 ]; then
    echo "Capture for $scene is still blank or missing; refusing to commit a broken screenshot." >&2
    exit 1
  fi
  mv "$capture" "$OUT/$scene.png"
  previous="$OUT/$scene.png"
  echo "Captured $OUT/$scene.png ($(wc -c < "$previous" | tr -d ' ') bytes)"
done
