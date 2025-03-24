#!/bin/bash

# Wait for Hyprland to set the instance signature
while [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; do
    sleep 0.1
    # Source the Hyprland instance signature
    if [ -f "/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.instance-$USER" ]; then
        source "/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.instance-$USER"
    fi
done

# Kill any existing wob instances
pkill wob 2>/dev/null

# Remove existing wob pipes
rm -f /tmp/*wob

# Create new pipes
mkfifo /tmp/$HYPRLAND_INSTANCE_SIGNATURE.volume.wob
mkfifo /tmp/$HYPRLAND_INSTANCE_SIGNATURE.brightness.wob

# Start wob instances
tail -f /tmp/$HYPRLAND_INSTANCE_SIGNATURE.volume.wob | \
    wob --background-color '#000000aa' \
        --bar-color '#5294e2' \
        --border-color '#5294e2aa' \
        --height 32 \
        --width 300 \
        --anchor top \
        --anchor center \
        --margin 100 &

tail -f /tmp/$HYPRLAND_INSTANCE_SIGNATURE.brightness.wob | \
    wob --background-color '#000000aa' \
        --bar-color '#f0c674' \
        --border-color '#f0c674aa' \
        --height 32 \
        --width 300 \
        --anchor top \
        --anchor center \
        --margin 150 &

# Keep the script running
wait
