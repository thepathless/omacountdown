#!/bin/bash
# Sends a desktop notification summary of the countdown
set -e

MSG_TITLE="${1:-Mimo Countdown}"
MSG_BODY="$2"
URGENT="$3"

URGENCY_FLAG="normal"
if [ "$URGENT" = "true" ] || [ "$URGENT" = "critical" ]; then
  URGENCY_FLAG="critical"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send \
    -a "Mimo Countdown" \
    -u "$URGENCY_FLAG" \
    -h "string:x-canonical-private-synchronous:mimo-countdown" \
    -i "preferences-system-time" \
    "$MSG_TITLE" \
    "$MSG_BODY" \
    -t 4000
fi
