#!/bin/bash
# Control brightness and update wob overlay

function send_notification {
    brightness=$(brightnessctl get)
    max_brightness=$(brightnessctl max)
    current_percent=$((brightness * 100 / max_brightness))
    echo $current_percent > /tmp/wob.sock
}

case $1 in
    up)
        brightnessctl set +5%
        send_notification
        ;;
    down)
        brightnessctl set 5%-
        send_notification
        ;;
esac
