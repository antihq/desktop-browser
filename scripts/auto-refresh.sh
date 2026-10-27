#!/bin/bash
# launchd entry point: keeps the app's 7-day profile alive automatically.
#
# Runs the full refresh only when the last success is older than
# MIN_AGE_DAYS; otherwise logs a skip and exits. Failed attempts
# (phone locked / off Wi-Fi / Mac asleep) retry at the next trigger.
#
# Log:   ~/Library/Logs/DesktopBrowser-refresh.log
# State: ~/Library/Application Support/DesktopBrowser/last-refresh

set -euo pipefail
cd "$(dirname "$0")/.."

STATE_DIR="$HOME/Library/Application Support/DesktopBrowser"
STATE_FILE="$STATE_DIR/last-refresh"
LOG_FILE="$HOME/Library/Logs/DesktopBrowser-refresh.log"
MIN_AGE_DAYS=5

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"

# Rotate the log once it passes 1 MB
if [[ -f "$LOG_FILE" ]] && (( $(stat -f%z "$LOG_FILE") > 1048576 )); then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"; }

# Skip if the current profile is fresh enough
if [[ -f "$STATE_FILE" ]]; then
    now=$(date +%s)
    last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    age_days=$(( (now - last) / 86400 ))
    if (( age_days < MIN_AGE_DAYS )); then
        log "Skip — profile refreshed ${age_days}d ago (< ${MIN_AGE_DAYS}d threshold)."
        exit 0
    fi
    log "Profile is ${age_days}d old — refreshing."
else
    log "No refresh on record — refreshing."
fi

if OUTPUT=$(./scripts/refresh-app.sh 2>&1); then
    date +%s > "$STATE_FILE"
    log "Refresh OK — profile clock reset."
    printf '%s\n' "$OUTPUT" | sed 's/^/    /' >> "$LOG_FILE"
else
    log "Refresh FAILED — will retry at next trigger."
    printf '%s\n' "$OUTPUT" | sed 's/^/    /' >> "$LOG_FILE"
    exit 1
fi
