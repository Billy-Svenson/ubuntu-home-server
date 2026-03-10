#!/bin/bash
###########################################################
# SSD Health Monitor — Uptime Kuma Push
# Runs hourly via cron, pushes status to Uptime Kuma
# Alerts via Telegram if any threshold is breached
###########################################################

PUSH_URL="http://YOUR_LAN_IP:3001/api/push/YOUR_PUSH_TOKEN"
DEVICE="/dev/nvme0n1"

# Thresholds
MAX_TEMP=70           # °C — warn at 70, critical at 83
MIN_SPARE=20          # % — warn if available spare drops below 20%
MAX_USED=80           # % — warn if drive wear hits 80%
MAX_ERRORS=50         # warn if error log entries exceed 50

###########################################################
# Read SMART data
###########################################################

SMART=$(sudo smartctl -A "$DEVICE" 2>/dev/null)

TEMP=$(echo "$SMART" | grep "^Temperature:" | awk '{print $2}')
SPARE=$(echo "$SMART" | grep "Available Spare:" | head -1 | awk '{print $3}' | tr -d '%')
USED=$(echo "$SMART" | grep "Percentage Used:" | awk '{print $3}' | tr -d '%')
ERRORS=$(echo "$SMART" | grep "Error Information Log Entries:" | awk '{print $5}')
INTEGRITY=$(echo "$SMART" | grep "Media and Data Integrity Errors:" | awk '{print $6}')

###########################################################
# Validate we got readings
###########################################################

if [ -z "$TEMP" ] || [ -z "$SPARE" ] || [ -z "$USED" ]; then
  curl -s "$PUSH_URL?status=down&msg=ERROR:+Could+not+read+SMART+data+from+$DEVICE&ping=" > /dev/null
  exit 1
fi

###########################################################
# Check thresholds
###########################################################

PROBLEMS=""

if [ "$TEMP" -ge "$MAX_TEMP" ]; then
  PROBLEMS="${PROBLEMS}TEMP:${TEMP}C "
fi

if [ "$SPARE" -le "$MIN_SPARE" ]; then
  PROBLEMS="${PROBLEMS}SPARE:${SPARE}% "
fi

if [ "$USED" -ge "$MAX_USED" ]; then
  PROBLEMS="${PROBLEMS}WEAR:${USED}% "
fi

if [ "$ERRORS" -ge "$MAX_ERRORS" ]; then
  PROBLEMS="${PROBLEMS}ERRORS:${ERRORS} "
fi

if [ "$INTEGRITY" != "0" ]; then
  PROBLEMS="${PROBLEMS}INTEGRITY_ERRORS:${INTEGRITY} "
fi

###########################################################
# Push result to Uptime Kuma
###########################################################

MSG="T:${TEMP}C Spare:${SPARE}% Wear:${USED}% Errors:${ERRORS}"

if [ -z "$PROBLEMS" ]; then
  # All good — push OK heartbeat
  curl -s "$PUSH_URL?status=up&msg=$(echo $MSG | sed 's/ /+/g')&ping=" > /dev/null
else
  # Problem detected — push down alert
  ALERT="SSD+ALERT:+$(echo $PROBLEMS | sed 's/ /+/g')"
  curl -s "$PUSH_URL?status=down&msg=${ALERT}&ping=" > /dev/null
fi
