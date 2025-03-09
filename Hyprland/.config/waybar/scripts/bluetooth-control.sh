#!/bin/bash

SERVICE="bluetooth.service"

case "$1" in
  toggle)
    # Check the current status of the Bluetooth service
    STATUS=$(systemctl is-active $SERVICE)

    if [ "$STATUS" == "active" ]; then
      # If active, stop the service
      notify-send "Bluetooth" "Disabling Bluetooth service..."
      sudo systemctl stop $SERVICE
    else
      # If inactive, start the service
      notify-send "Bluetooth" "Enabling Bluetooth service..."
      sudo systemctl start $SERVICE
    fi
    ;;
  enable)
    # Explicitly enable the service
    sudo systemctl start $SERVICE
    notify-send "Bluetooth" "Bluetooth service enabled."
    ;;
  disable)
    # Explicitly disable the service
    sudo systemctl stop $SERVICE
    notify-send "Bluetooth" "Bluetooth service disabled."
    ;;
  *)
    echo "Usage: $0 {toggle|enable|disable}"
    exit 1
    ;;
esac

