#!/bin/bash

# Check if the waybar-disabled file exists
if [ -f ~/.cache/waybar-disabled ]; then
    # Remove the file to enable Waybar
    rm ~/.cache/waybar-disabled
    # Restart Waybar
    ~/.config/waybar/launch.sh &
else
    # Create the file to disable Waybar
    touch ~/.cache/waybar-disabled
    # Stop Waybar
    pkill waybar
fi

