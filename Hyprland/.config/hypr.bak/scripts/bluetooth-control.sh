#!/bin/bash
# ~/.config/hypr/scripts/bluetooth-control.sh

notify() {
    notify-send "Bluetooth" "$1" -r 9999
}

case "$1" in
    "toggle")
        if systemctl is-active bluetooth.service > /dev/null; then
            sudo systemctl stop bluetooth.service
            killall blueberry-tray 2>/dev/null
            notify "Servicio detenido"
        else
            sudo systemctl start bluetooth.service
            sleep 2  # Esperar a que el servicio inicie
            blueberry-tray &
            notify "Servicio iniciado"
        fi
        ;;
    "start")
        if ! systemctl is-active bluetooth.service > /dev/null; then
            sudo systemctl start bluetooth.service
            sleep 2
            blueberry-tray &
            notify "Servicio iniciado"
        else
            notify "El servicio ya está activo"
        fi
        ;;
    "stop")
        if systemctl is-active bluetooth.service > /dev/null; then
            killall blueberry-tray 2>/dev/null
            sudo systemctl stop bluetooth.service
            notify "Servicio detenido"
        else
            notify "El servicio ya está detenido"
        fi
        ;;
    "status")
        if systemctl is-active bluetooth.service > /dev/null; then
            notify "Servicio activo"
        else
            notify "Servicio inactivo"
        fi
        ;;
    *)
        echo "Uso: bluetooth-control.sh {toggle|start|stop|status}"
        exit 1
        ;;
esac


