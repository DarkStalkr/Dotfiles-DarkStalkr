#!/bin/bash

# Log file for debugging
LOGFILE="$HOME/.config/waybar/launch.log"

# Check if waybar-disabled file exists
if [ -f $HOME/.cache/waybar-disabled ] ;then 
    echo "$(date): Waybar is disabled" >> "$LOGFILE"
    exit 1 
fi

# Quit all running waybar instances
killall waybar
pkill waybar
sleep 0.2

# Loading the default configuration and style
config_file="config-hypr"
style_file="style.css"

# Launch Waybar with the specified configuration and style
waybar -c ~/.config/waybar/$config_file -s ~/.config/waybar/$style_file >> "$LOGFILE" 2>&1 &

