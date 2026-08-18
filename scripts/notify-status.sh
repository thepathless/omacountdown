#!/usr/bin/env bash
# Sends a desktop notification summary of the countdown for OmaCountdown
set -e

MSG_TITLE="${1:-OmaCountdown}"
MSG_BODY="$2"
URGENT="$3"

URGENCY_FLAG="normal"
if [ "$URGENT" = "true" ] || [ "$URGENT" = "critical" ]; then
  URGENCY_FLAG="critical"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send \
    -a "OmaCountdown" \
    -u "$URGENCY_FLAG" \
    -h "string:x-canonical-private-synchronous:omacountdown" \
    -i "preferences-system-time" \
    "$MSG_TITLE" \
    "$MSG_BODY" \
    -t 5000
fi
