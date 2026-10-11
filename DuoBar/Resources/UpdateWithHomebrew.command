#!/bin/bash
set -euo pipefail
TAP_CASK="squazaryu/tap/t-duobar"
APP="/Applications/DuoBar.app"
SUPPORT="$HOME/Library/Application Support/T-DuoBar"
MANUAL_BACKUP=""
if [[ -x /opt/homebrew/bin/brew ]]; then BREW=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then BREW=/usr/local/bin/brew
else
    echo 'Homebrew is not installed. Install it from https://brew.sh, then retry.' >&2
    exit 1
fi
mkdir -p "$SUPPORT/Updater"
LOCK="$SUPPORT/Updater/install.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "An update is already running. If a previous Terminal was force-closed, remove: $LOCK" >&2
    exit 1
fi
finish() {
    result=$?
    if [[ "$result" != 0 && -n "$MANUAL_BACKUP" && ! -e "$APP" ]]; then mv "$MANUAL_BACKUP" "$APP"; fi
    if [[ -d "$APP" ]]; then /usr/bin/open -n "$APP" || true; fi
    rmdir "$LOCK" 2>/dev/null || true
    if [[ "$result" == 0 ]]; then echo 'DuoBar updated. You can close this Terminal window.'
    else echo 'Update failed. The previous app was preserved where possible. Read the error above.' >&2; fi
}
trap finish EXIT
printf 'Updating %s with Homebrew…\n' "$TAP_CASK"
"$BREW" update
pkill -u "$(id -u)" -x DuoBar >/dev/null 2>&1 || true
for attempt in {1..30}; do pgrep -u "$(id -u)" -x DuoBar >/dev/null || break; sleep 0.1; done
if pgrep -u "$(id -u)" -x DuoBar >/dev/null; then echo 'Please quit DuoBar and retry.' >&2; exit 1; fi
if "$BREW" list --cask t-duobar >/dev/null 2>&1; then
    "$BREW" upgrade --cask --no-ask "$TAP_CASK"
else
    if [[ -d "$APP" ]]; then
        mkdir -p "$SUPPORT/Backups"
        MANUAL_BACKUP="$SUPPORT/Backups/DuoBar-before-homebrew-$(date -u +%Y%m%dT%H%M%SZ)-$$.app"
        mv "$APP" "$MANUAL_BACKUP"
        printf 'Previous app saved: %s\n' "$MANUAL_BACKUP"
    fi
    "$BREW" install --cask --no-ask "$TAP_CASK"
fi
/usr/bin/codesign --verify --deep --strict "$APP"
