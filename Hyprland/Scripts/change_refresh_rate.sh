#!/bin/bash

# Define your monitor
MONITOR="eDP-1"

# Path to the battery status file
BATTERY_STATUS="/sys/class/power_supply/BAT0/status"

# Read the current battery status
STATUS=$(cat $BATTERY_STATUS)

# Define refresh rates and scales
ON_BATTERY_RATE="60"
ON_BATTERY_SCALE="2"
PLUGGED_IN_RATE="165"
PLUGGED_IN_SCALE="2"

# Use hyprctl to change the monitor configuration based on power status
if [ "$STATUS" == "Discharging" ]; then
  hyprctl keyword monitor $MONITOR,3072x1920@$ON_BATTERY_RATE,0x0,$ON_BATTERY_SCALE
else
  hyprctl keyword monitor $MONITOR,3072x1920@$PLUGGED_IN_RATE,0x0,$PLUGGED_IN_SCALE
fi

