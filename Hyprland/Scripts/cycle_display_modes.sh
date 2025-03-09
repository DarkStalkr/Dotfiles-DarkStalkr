#!/bin/bash

STATE_FILE="/home/sohighman/Documents/Scripts/display_mode_state.txt"

# Ensure the state file exists; initialize if not
if [[ ! -f $STATE_FILE ]]; then
    echo "2" > $STATE_FILE
fi

# Read the current mode
mode=$(cat $STATE_FILE)

# Update to the next mode
if [ "$mode" -eq 2 ]; then
    mode=3
else
    mode=2
fi

echo "Switching to mode $mode"

# Apply the configuration based on mode
case $mode in
    2)
        # Only External Monitor
        echo "Applying only external monitor"
        wlr-randr --output eDP-1 --off
        sleep 1  # Ensure the laptop screen turns off properly
        wlr-randr --output HDMI-A-1 --on
        ;;
    3)
        # Extended Screen
        echo "Setting up extended screen"
        wlr-randr --output eDP-1 --on
        wlr-randr --output HDMI-A-1 --on --pos $(wlr-randr | grep -oP 'eDP-1.*?px' | grep -oP '\d*x\d*') 
        ;;
esac

# Save the new mode to the state file
echo $mode > $STATE_FILE

