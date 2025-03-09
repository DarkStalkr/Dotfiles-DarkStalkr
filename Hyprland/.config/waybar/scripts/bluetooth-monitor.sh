#!/bin/bash

if systemctl is-active bluetooth.service > /dev/null; then
    if [ "$(bluetoothctl show | grep "Powered: yes" | wc -l)" -eq 1 ]; then
        echo '{"text": "󰂯", "class": "on", "tooltip": "Bluetooth activo"}'
    else
        echo '{"text": "󰂯", "class": "on", "tooltip": "Bluetooth inactivo pero servicio corriendo"}'
    fi
else
    echo '{"text": "󰂲", "class": "off", "tooltip": "Servicio detenido"}'
fi
