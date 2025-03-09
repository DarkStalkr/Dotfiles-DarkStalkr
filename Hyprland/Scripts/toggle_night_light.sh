#!/bin/bash

STATUS_FILE="/tmp/night_light_status"
INTENSITY_FILE="/tmp/night_light_intensity"

if [ -f "$STATUS_FILE" ]; then
    rm "$STATUS_FILE"
    pkill gammastep
else
    touch "$STATUS_FILE"
    if [ -f "$INTENSITY_FILE" ]; then
        INTENSITY=$(cat "$INTENSITY_FILE")
    else
        INTENSITY=3000
    fi
    gammastep -O $INTENSITY &
fi

