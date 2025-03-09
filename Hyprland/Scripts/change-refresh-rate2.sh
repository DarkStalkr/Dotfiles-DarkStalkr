#!/bin/bash

LOG_FILE="/home/sohighman/Documents/Scripts/change_refresh_rate.log"

echo "Running change_refresh_rate2.sh at $(date)" >> $LOG_FILE
echo "HYPRLAND_INSTANCE_SIGNATURE: $HYPRLAND_INSTANCE_SIGNATURE" >> $LOG_FILE

# Get the power status
POWER_STATUS=$(cat /sys/class/power_supply/AC/online)
echo "Power status: $POWER_STATUS" >> $LOG_FILE

if [ "$POWER_STATUS" == "1" ]; then
    # AC connected
    echo "Battery status: Charging" >> $LOG_FILE
    hyprctl keyword monitor eDP-1,3072x1920@165,0x0,2
    echo "Changed to plugged-in settings: 165 Hz" >> $LOG_FILE
else
    # Battery
    echo "Battery status: Discharging" >> $LOG_FILE
    hyprctl keyword monitor eDP-1,3072x1920@60,0x0,2
    echo "Changed to battery settings: 60 Hz" >> $LOG_FILE
fi

echo "Script finished at $(date)" >> $LOG_FILE

