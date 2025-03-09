#!/bin/bash

# Define your monitor
MONITOR="eDP-1"

# Path to store the current refresh rate state
REFRESH_STATE_FILE="$HOME/.config/hypr/current_refresh_rate"

# Check if the state file exists, otherwise initialize it to 165Hz
if [ ! -f "$REFRESH_STATE_FILE" ]; then
    echo "165" > "$REFRESH_STATE_FILE"
fi

# Read the current refresh rate from the state file
CURRENT_REFRESH_RATE=$(cat "$REFRESH_STATE_FILE")
echo "Current refresh rate: $CURRENT_REFRESH_RATE" >> "$HOME/Documents/Scripts/change_refresh_rate.log"

# Toggle the refresh rate
if [ "$CURRENT_REFRESH_RATE" == "165" ]; then
    NEW_REFRESH_RATE="60"
else
    NEW_REFRESH_RATE="165"
fi
echo "New refresh rate: $NEW_REFRESH_RATE" >> "$HOME/Documents/Scripts/change_refresh_rate.log"

# Apply the new refresh rate using hyprctl
hyprctl keyword monitor $MONITOR,3072x1920@$NEW_REFRESH_RATE,0x0,2.00

# Check if the hyprctl command was successful
if [ $? -eq 0 ]; then
    echo "$NEW_REFRESH_RATE" > "$REFRESH_STATE_FILE"
    echo "Refresh rate updated to $NEW_REFRESH_RATE" >> "$HOME/Documents/Scripts/change_refresh_rate.log"
else
    echo "Failed to update refresh rate" >> "$HOME/Documents/Scripts/change_refresh_rate.log"
fi

