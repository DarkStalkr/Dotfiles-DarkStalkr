//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import "modules"
import "services"
import "config"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    Component.onCompleted: {
        Application.organization = "HyprUI"
        Application.domain = "hyprui.org"
        Application.name = "HyprUI_Shell"
    }

    // HYPRUI THEME SWAP
    GlobalShortcut {
        appid: "hyprui"
        name: "cycle_theme"
        onPressed: HyprUITheme.cycle()
    }

    // HYPRUI LAUNCHER
    GlobalShortcut {
        appid: "hyprui"
        name: "toggle_launcher"
        onPressed: UI.toggleLauncher()
    }

    // HYPRUI PANEL SIZING
    GlobalShortcut {
        appid: "hyprui"
        name: "cycle_panel_size"
        description: "Cycle top bar between large / medium / small presets"
        onPressed: UI.cycleSize()
    }

    // HYPRUI VOLUME
    GlobalShortcut {
        appid: "hyprui"
        name: "increase_volume"
        onPressed: Audio.increaseVolume()
    }
    GlobalShortcut {
        appid: "hyprui"
        name: "decrease_volume"
        onPressed: Audio.decreaseVolume()
    }
    GlobalShortcut {
        appid: "hyprui"
        name: "toggle_mute"
        onPressed: Audio.toggleMute()
    }

    // HYPRUI BRIGHTNESS
    GlobalShortcut {
        appid: "hyprui"
        name: "increase_brightness"
        onPressed: Brightness.increase()
    }
    GlobalShortcut {
        appid: "hyprui"
        name: "decrease_brightness"
        onPressed: Brightness.decrease()
    }

    // Fork-qs popup widget system (FloatingWindow — single instance for all widgets)
    Loader { 
        id: popupLoader
        source: "popups/PopupManager.qml" 
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: { if (!ipcPoller.running) ipcPoller.running = true; }
    }

    Process {
        id: ipcPoller
        command: ["bash", "-c", "if [ -f /tmp/qs_widget_state ]; then cat /tmp/qs_widget_state; rm /tmp/qs_widget_state; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rawCmd = this.text.trim();
                if (rawCmd === "") return;

                if (!popupLoader.item) {
                    popupLoader.active = false;
                    popupLoader.active = true;
                }

                if (popupLoader.item) {
                    popupLoader.item.handleIpc(rawCmd);
                }
            }
        }
    }

    // Per-screen components
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                required property ShellScreen modelData

                TopBar             { screen: modelData }
                HyprOSD            { screen: modelData }
                MediaPanel         { screen: modelData }
                Launcher           { screen: modelData }
                NotificationPopups { screen: modelData }
            }
        }
    }
}
