import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "../services"
import "../components"

Scope {
    id: root
    required property ShellScreen screen

PanelWindow {
    id: barWindow
    screen: root.screen

    WlrLayershell.namespace: "hyprui-topbar"

    anchors {
        top: true
        left: true
        right: true
    }

    // Bar height and spacing — reactive to HyprUI size presets
    implicitHeight: UI.panelThickness
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    margins { top: UI.panelMargin; bottom: 0; left: 4; right: 4 }
    exclusiveZone: UI.exclusiveZone
    color: "transparent"

    // ─── Theme bridge ────────────────────────────────────────────────────────
    // Structural / accent colors react to HyprUITheme.cycle().
    // Palette-specific colors (peach, yellow…) fall back to MatugenColors defaults
    // so they still update when the user later enables Matugen mode.
    MatugenColors { id: _matugen }

    QtObject {
        id: mocha
        // Structural — from HyprUITheme (cycle-reactive)
        readonly property color base:     HyprUITheme.useMatugen ? _matugen.base : Qt.color(HyprUITheme.active.background)
        readonly property color surface0: HyprUITheme.useMatugen ? _matugen.surface0 : Qt.color(HyprUITheme.active.surface)
        readonly property color surface1: HyprUITheme.useMatugen ? _matugen.surface1 : Qt.lighter(Qt.color(HyprUITheme.active.surface), 1.12)
        readonly property color surface2: HyprUITheme.useMatugen ? _matugen.surface2 : Qt.lighter(Qt.color(HyprUITheme.active.surface), 1.25)
        readonly property color crust:    HyprUITheme.useMatugen ? _matugen.crust : Qt.darker(Qt.color(HyprUITheme.active.background), 1.3)
        readonly property color text:     HyprUITheme.useMatugen ? _matugen.text : Qt.color(HyprUITheme.active.text)
        readonly property color subtext0: HyprUITheme.useMatugen ? _matugen.subtext0 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.65)
        readonly property color subtext1: HyprUITheme.useMatugen ? _matugen.subtext1 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.80)
        readonly property color overlay0: HyprUITheme.useMatugen ? _matugen.overlay0 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.30)
        readonly property color overlay2: HyprUITheme.useMatugen ? _matugen.overlay2 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.45)
        // Accent — HyprUITheme.primary (volume accent) + secondary (brightness accent)
        readonly property color blue:     HyprUITheme.useMatugen ? _matugen.blue : HyprUITheme.primary
        readonly property color mauve:    HyprUITheme.useMatugen ? _matugen.mauve : HyprUITheme.primary
        readonly property color sapphire: HyprUITheme.useMatugen ? _matugen.sapphire : HyprUITheme.secondary
        // Semantic
        readonly property color green:    HyprUITheme.useMatugen ? _matugen.green : Qt.color(HyprUITheme.active.green)
        readonly property color red:      HyprUITheme.useMatugen ? _matugen.red : Qt.color(HyprUITheme.active.error)
        // Palette — MatugenColors (updated by Matugen when user enables it)
        readonly property color peach:    _matugen.peach
        readonly property color yellow:   _matugen.yellow
        readonly property color pink:     _matugen.pink
        readonly property color teal:     _matugen.teal
        readonly property color maroon:   _matugen.maroon
        readonly property color lavender: _matugen.lavender
    }

    // --- State Variables ---
    
    // Triggers layout animations immediately to feel fast
    property bool isStartupReady: false
    Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
    
    // Prevents repeaters (Workspaces/Tray) from flickering on data updates
    property bool startupCascadeFinished: false
    Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
    
    property string timeStr: ""
    property string fullDateStr: ""
    property int typeInIndex: 0
    property string dateStr: fullDateStr.substring(0, typeInIndex)

    property string weatherIcon: Weather.icon
    property string weatherTemp: Weather.temp
    property string weatherHex: mocha.yellow
    
    // WiFi — reactive to Network service, no polling
    readonly property string wifiSsid: Network.network?.ssid ?? ""
    readonly property string wifiIcon: {
        if (!Network.wifiEnabled || !Network.network) return "󰤮";
        let s = Network.network?.strength ?? 0;
        if (s > 80) return "󰤨"; if (s > 60) return "󰤥";
        if (s > 40) return "󰤢"; if (s > 20) return "󰤟";
        return "󰤯";
    }

    // BT — still needs polling (no native service)
    property string btStatus: "Off"
    property string btIcon: "󰂲"
    property string btDevice: ""

    // Volume — reactive to Audio service, no polling
    readonly property string volPercent: Math.round(Audio.volume * 100) + "%"
    readonly property bool isMuted: Audio.muted
    readonly property string volIcon: {
        if (Audio.muted || Audio.volume <= 0) return "󰝟";
        if (Audio.volume > 0.7) return "󰕾";
        if (Audio.volume > 0.3) return "󰖀";
        return "󰕿";
    }
    
    // Battery — sourced from UPower (native, no shell polling)
    readonly property real   _batPct:     UPower.displayDevice.percentage * 100
    readonly property bool   isCharging:  UPower.displayDevice.state === UPowerDeviceState.Charging ||
                                          UPower.displayDevice.state === UPowerDeviceState.FullyCharged
    readonly property int    batCap:      Math.round(_batPct)
    readonly property string batPercent:  batCap + "%"
    readonly property string batIcon: {
        if (isCharging)    return "󰂄"
        if (batCap > 90)   return "󰁹"
        if (batCap > 70)   return "󰁾"
        if (batCap > 50)   return "󰁽"
        if (batCap > 30)   return "󰁻"
        if (batCap > 15)   return "󰁺"
        return "󰪫"
    }

    property string kbLayout: "us"
    property bool   kbJustChanged: false
    property string _prevBtDevice: ""

    // Media — reactive to Players (MPRIS) service, no polling
    // MprisPlaybackStatus: Stopped=0, Playing=1, Paused=2
    readonly property bool isMediaActive: {
        let p = Players.active;
        return p !== null && p !== undefined &&
               p.playbackState !== MprisPlaybackState.Stopped &&
               (p.trackTitle ?? "") !== "";
    }
    readonly property string mediaTitle:   Players.active?.trackTitle ?? ""
    readonly property string mediaArtUrl:  Players.active?.trackArtUrl ?? ""
    readonly property string mediaTimeStr: {
        let p = Players.active;
        if (!p) return "";
        function fmt(s) { let m=Math.floor(s/60), sec=Math.floor(s%60); return m+":"+(sec<10?"0":"")+sec; }
        return fmt(p.position ?? 0) + " / " + fmt(p.trackDuration ?? 0);
    }

    // Derived
    readonly property bool isWifiOn:    Network.wifiEnabled
    readonly property bool isBtOn:      btStatus.trim().toLowerCase() === "on" || btStatus.trim().toLowerCase() === "enabled"
    readonly property bool isSoundActive: !Audio.muted && Audio.volume > 0
    property color batDynamicColor: {
        if (isCharging)    return mocha.green
        if (batCap >= 70)  return mocha.blue
        if (batCap >= 30)  return mocha.yellow
        return mocha.red
    }

    function formatSeconds(seconds) {
        if (isNaN(seconds) || seconds <= 0) return "--:--";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);
        if (h > 0) {
            return h + ":" + (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
        }
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    // Bluetooth connect/disconnect notifications
    onBtDeviceChanged: {
        if (!barWindow.startupCascadeFinished) {
            barWindow._prevBtDevice = barWindow.btDevice
            return
        }
        if (barWindow.btDevice !== "" && barWindow._prevBtDevice === "") {
            Quickshell.execDetached(["notify-send", "-i", "bluetooth-active", "-u", "normal", "-t", "3000",
                "Bluetooth Connected", "󰂱  " + barWindow.btDevice])
        } else if (barWindow.btDevice === "" && barWindow._prevBtDevice !== "") {
            Quickshell.execDetached(["notify-send", "-i", "bluetooth", "-u", "low", "-t", "2000",
                "Bluetooth", "󰂲  Device disconnected"])
        }
        barWindow._prevBtDevice = barWindow.btDevice
    }

    // Keyboard layout flash reset
    Timer { id: kbFlashTimer; interval: 1200; running: false; repeat: false; onTriggered: barWindow.kbJustChanged = false }

    // ==========================================
    // DATA FETCHING (PROCESSES & TIMERS)
    // ==========================================

    // BT poller — uses sys_info.sh (avoids embedding nerd-font chars in QML template literals)
    Process {
        id: btPoller
        running: false
        command: ["bash", "-c",
            `SYS="${Quickshell.env("HOME")}/.config/hyprui-v2/popups/sys_info.sh"; ` +
            `printf '%s\n%s\n%s\n' "$("$SYS" --bt-status)" "$("$SYS" --bt-icon)" "$("$SYS" --bt-connected)"`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(l => l.trim()).filter(l => l !== "");
                if (lines.length >= 1) {
                    barWindow.btStatus = lines[0];   // "on" | "off"
                    if (lines.length >= 2) barWindow.btIcon = lines[1];
                    let dev = lines.length >= 3 ? lines[2] : "";
                    barWindow.btDevice = (dev === "Disconnected" || dev === "Off") ? "" : dev;
                }
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: btPoller.running = true }

    // KB layout — polling approach (reliable; events not stable across all Quickshell builds)
    Process {
        id: kbPoller
        running: false
        command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[].active_keymap' | sort -u | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let full = this.text.trim();
                if (full === "") return;
                // Shorten to 2-char code, e.g. "English (US)" → "EN", "Spanish (Latin American)" → "SP"
                let code = full.substring(0, 2).toUpperCase();
                if (code !== barWindow.kbLayout) {
                    if (barWindow.startupCascadeFinished) {
                        Quickshell.execDetached(["notify-send", "-i", "input-keyboard", "-u", "low",
                            "-t", "2000", "Keyboard Layout", "⌨  " + full]);
                        barWindow.kbJustChanged = true;
                        kbFlashTimer.restart();
                    }
                    barWindow.kbLayout = code;
                }
            }
        }
    }
    // Seed at startup
    Timer { interval: 800; running: true; repeat: false; onTriggered: kbPoller.running = true }
    // Background refresh every 5 s — catches changes from hotkeys or external tools
    Timer { interval: 5000; running: true; repeat: true; onTriggered: kbPoller.running = true }


    // Native Qt Time Formatting
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            barWindow.timeStr = Qt.formatDateTime(d, "hh:mm:ss AP");
            barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
            if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                barWindow.typeInIndex = barWindow.fullDateStr.length;
            }
        }
    }

    // Typewriter effect timer for the date
    Timer {
        id: typewriterTimer
        interval: 40
        running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
        repeat: true
        onTriggered: barWindow.typeInIndex += 1
    }

    // ==========================================
    // UI LAYOUT
    // ==========================================
    Item {
        anchors.fill: parent

        // ---------------- LEFT ----------------
        RowLayout {
            id: leftLayout
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 

            // Staggered Main Transition
            property bool showLayout: false
            opacity: showLayout ? 1 : 0
            transform: Translate {
                x: leftLayout.showLayout ? 0 : -30
                Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }
            
            Timer {
                running: barWindow.isStartupReady
                interval: 10
                onTriggered: leftLayout.showLayout = true
            }

            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            property int moduleHeight: UI.panelThickness

            // Search 
            Rectangle {
                property bool isHovered: searchMouse.containsMouse
                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                radius: 14; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                Layout.preferredHeight: parent.moduleHeight; Layout.preferredWidth: 48
                
                scale: isHovered ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰍉"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 24
                    color: parent.isHovered ? mocha.blue : mocha.text
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    id: searchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: UI.toggleLauncher()
                }
            }

            // Notifications
            Rectangle {
                property bool isHovered: notifMouse.containsMouse
                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                radius: 14; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                Layout.preferredHeight: parent.moduleHeight; Layout.preferredWidth: 48
                
                scale: isHovered ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                    color: parent.isHovered ? mocha.yellow : mocha.text
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    id: notifMouse
                    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
                        if (mouse.button === Qt.RightButton) Quickshell.execDetached(["swaync-client", "-d"]);
                    }
                }
            }

            // Workspaces 
            Rectangle {
                id: wsBox
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                radius: 14; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                Layout.preferredHeight: parent.moduleHeight
                clip: true
                
                property real targetWidth: Hypr.workspaces.values.length > 0 ? wsLayout.implicitWidth + 20 : 0
                Layout.preferredWidth: targetWidth
                visible: targetWidth > 0
                opacity: Hypr.workspaces.values.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                RowLayout {
                    id: wsLayout
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Repeater {
                        model: Hypr.workspaces.values
                        delegate: Rectangle {
                            id: wsPill
                            required property var modelData
                            required property int index
                            property bool isHovered: wsPillMouse.containsMouse

                            // Native Quickshell.Hyprland binding — fully reactive
                            property string wsName: modelData.name !== "" ? modelData.name : modelData.id.toString()
                            property bool _isActive: modelData.id === Hypr.activeWsId
                            property bool _isOccupied: {
                                let tvs = Hypr.toplevels.values
                                for (let i = 0; i < tvs.length; i++) {
                                    if (tvs[i].workspace && tvs[i].workspace.id === modelData.id) return true
                                }
                                return false
                            }
                            property string stateLabel: _isActive ? "active" : (_isOccupied ? "occupied" : "empty")
                            
                            property real pillWidth: 32
                            Layout.preferredWidth: pillWidth
                            Behavior on pillWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            
                            Layout.preferredHeight: 32; radius: 10
                            
                            color: stateLabel === "active" 
                                    ? mocha.mauve 
                                    : (isHovered 
                                        ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.9) 
                                        : (stateLabel === "occupied" 
                                            ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.9) 
                                            : "transparent"))

                            scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            
                            property bool initAnimTrigger: false
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate {
                                y: wsPill.initAnimTrigger ? 0 : 15
                                Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                            }

                            Component.onCompleted: {
                                if (!barWindow.startupCascadeFinished) {
                                    animTimer.interval = index * 60;
                                    animTimer.start();
                                } else {
                                    initAnimTrigger = true;
                                }
                            }

                            Timer {
                                id: animTimer
                                running: false
                                repeat: false
                                onTriggered: wsPill.initAnimTrigger = true
                            }
                            
                            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 250 } }

                            Text {
                                anchors.centerIn: parent
                                text: wsName
                                font.family: "JetBrains Mono"
                                font.pixelSize: UI.fontSize.sm
                                font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                
                                color: stateLabel === "active" 
                                        ? mocha.crust 
                                        : (isHovered 
                                            ? mocha.text 
                                            : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                                        
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                            MouseArea {
                                id: wsPillMouse
                                hoverEnabled: true
                                anchors.fill: parent
                                onClicked: Hypr.dispatch("workspace " + wsName)
                            }
                        }
                    }
                }
            }

            // Media Player 
            Rectangle {
                id: mediaBox
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                radius: 14; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                Layout.preferredHeight: parent.moduleHeight
                clip: true 
                
                // Fixed width: art(32) + spacing(10) + text cap(150) + gap(16) + controls(92) + margins(24)
                property real desiredWidth: barWindow.isMediaActive ? Math.min(324, mediaBox.availableWidth) : 0
                
                // Stable available width calculation to avoid polish loop and collision
                readonly property real otherItemsWidth: 48 + 4 + 48 + 4 + wsBox.width + 4
                readonly property real availableWidth: (barWindow.width / 2) - (centerBox.width / 2) - otherItemsWidth - 20
                
                Layout.preferredWidth: Math.min(desiredWidth, Math.max(0, availableWidth))
                visible: Layout.preferredWidth > 0 || opacity > 0
                opacity: barWindow.isMediaActive ? 1.0 : 0.0

                // Premium smooth slide expansion
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 400 } }
                
                Item {
                    id: mediaLayoutContainer
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: parent.height
                    
                    // Interior parallax slide effect
                    opacity: barWindow.isMediaActive ? 1.0 : 0.0
                    transform: Translate { 
                        x: barWindow.isMediaActive ? 0 : -20 
                        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                    }
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    RowLayout {
                        id: innerMediaLayout
                        anchors.fill: parent
                        spacing: 16
                        
                        MouseArea {
                            id: mediaInfoMouse
                            Layout.fillWidth: true
                            Layout.minimumWidth: 40
                            Layout.fillHeight: true
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hyprui-v2/popups/qs_manager.sh toggle music`])
                            
                            RowLayout {
                                id: infoLayout
                                anchors.fill: parent
                                spacing: 10
                                
                                scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                Rectangle {
                                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 8; color: mocha.surface1
                                    border.width: Players.active?.playbackState === MprisPlaybackState.Playing ? 1 : 0
                                    border.color: mocha.mauve
                                    clip: true
                                    Image { 
                                        anchors.fill: parent; 
                                        source: barWindow.mediaArtUrl || "";
                                        fillMode: Image.PreserveAspectCrop 
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                    }
                                }
                                ColumnLayout {
                                    spacing: -2
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 150

                                    Text {
                                        text: barWindow.mediaTitle;
                                        font.family: "JetBrains Mono";
                                        font.weight: Font.Black;
                                        font.pixelSize: 13;
                                        color: mocha.text;
                                        elide: Text.ElideRight;
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: barWindow.mediaTimeStr;
                                        font.family: "JetBrains Mono";
                                        font.weight: Font.Black;
                                        font.pixelSize: 10;
                                        color: mocha.subtext0;
                                        elide: Text.ElideRight;
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        RowLayout {
                            id: mediaControls
                            Layout.alignment: Qt.AlignRight
                            Layout.fillWidth: false
                            spacing: 8
                            Item { 
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24; 
                                Text { 
                                    anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: 26; 
                                    color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    scale: prevMouse.containsMouse ? 1.1 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "previous"]) } 
                            }
                            Item { 
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28; 
                                Text { 
                                    anchors.centerIn: parent; text: Players.active?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: 30;
                                    color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    scale: playMouse.containsMouse ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "play-pause"]) } 
                            }
                            Item { 
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24; 
                                Text { 
                                    anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: 26; 
                                    color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    scale: nextMouse.containsMouse ? 1.1 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "next"]) } 
                            }
                        }
                    }
                }
            }
        }

        // ---------------- CENTER ----------------
        Rectangle {
            id: centerBox
            anchors.centerIn: parent
            property bool isHovered: centerMouse.containsMouse
            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
            radius: 14; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
            height: UI.panelThickness
            
            width: centerLayout.implicitWidth + 36
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
            
            // Staggered Center Transition
            property bool showLayout: false
            opacity: showLayout ? 1 : 0
            transform: Translate {
                y: centerBox.showLayout ? 0 : -30
                Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }

            Timer {
                running: barWindow.isStartupReady
                interval: 150
                onTriggered: centerBox.showLayout = true
            }

            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            // Hover Scaling
            scale: isHovered ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 250 } }
            
            MouseArea {
                id: centerMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hyprui-v2/popups/qs_manager.sh toggle calendar`])
            }

            RowLayout {
                id: centerLayout
                anchors.centerIn: parent
                spacing: 24

                // Clockbox
                ColumnLayout {
                    spacing: -2
                    Text { text: barWindow.timeStr; font.family: "JetBrains Mono"; font.pixelSize: UI.fontSize.md; font.weight: Font.Black; color: mocha.blue }
                    Text { text: barWindow.dateStr; font.family: "JetBrains Mono"; font.pixelSize: UI.fontSize.sm; font.weight: Font.Bold; color: mocha.subtext0 }
                }

                // Weatherbox
                RowLayout {
                    spacing: 8
                    Text { 
                        text: barWindow.weatherIcon; 
                        font.family: "Iosevka Nerd Font";
                        font.pixelSize: UI.fontSize.lg;
                        color: Qt.tint(barWindow.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4))
                    }
                    Text { text: barWindow.weatherTemp; font.family: "JetBrains Mono"; font.pixelSize: UI.fontSize.md; font.weight: Font.Black; color: mocha.peach }
                }
            }
        }

        // ---------------- RIGHT ----------------
        RowLayout {
            id: rightLayout
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Staggered Right Transition
            property bool showLayout: false
            opacity: showLayout ? 1 : 0
            transform: Translate {
                x: rightLayout.showLayout ? 0 : 30
                Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }
            
            Timer {
                running: barWindow.isStartupReady
                interval: 250
                onTriggered: rightLayout.showLayout = true
            }

            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            // Dedicated System Tray Pill
            Rectangle {
                height: UI.panelThickness
                radius: 20
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                border.width: 1
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                
                property real targetWidth: trayRepeater.count > 0 ? trayLayout.implicitWidth + 24 : 0
                Layout.preferredWidth: targetWidth
                Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                
                visible: targetWidth > 0
                opacity: targetWidth > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                RowLayout {
                    id: trayLayout
                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items
                        delegate: Image {
                            id: trayIcon
                            source: modelData.icon || ""
                            fillMode: Image.PreserveAspectFit
                            
                            sourceSize: Qt.size(18, 18)
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            
                            property bool isHovered: trayMouse.containsMouse
                            property bool initAnimTrigger: false
                            opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                            scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                            Component.onCompleted: {
                                if (!barWindow.startupCascadeFinished) {
                                    trayAnimTimer.interval = index * 50;
                                    trayAnimTimer.start();
                                } else {
                                    initAnimTrigger = true;
                                }
                            }
                            Timer {
                                id: trayAnimTimer
                                running: false
                                repeat: false
                                onTriggered: trayIcon.initAnimTrigger = true
                            }

                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                            QsMenuAnchor {
                                id: menuAnchor
                                anchor.window: barWindow
                                anchor.item: trayIcon
                                menu: modelData.menu
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.menu) {
                                            menuAnchor.open();
                                        } else if (typeof modelData.contextMenu === "function") {
                                            modelData.contextMenu(mouse.x, mouse.y);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // System Elements Pill
            Rectangle {
                height: UI.panelThickness
                radius: 20
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                border.width: 1
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                
                property real targetWidth: sysLayout.implicitWidth + 20
                Layout.preferredWidth: targetWidth
                Behavior on targetWidth { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }

                RowLayout {
                    id: sysLayout
                    anchors.centerIn: parent
                    spacing: 8 

                    property int pillHeight: Math.round(UI.panelThickness * 0.7)

                    // KB
                    Rectangle {
                        id: kbPill
                        property bool isHovered: kbMouse.containsMouse
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                        radius: 10; Layout.preferredHeight: sysLayout.pillHeight;
                        clip: true

                        property real targetWidth: kbLayoutRow.implicitWidth + 24
                        Layout.preferredWidth: targetWidth
                        Behavior on targetWidth { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Cascading entrance animation
                        property bool initAnimTrigger: false
                        Component.onCompleted: { if (!barWindow.startupCascadeFinished) { kbtimer.start() } else { initAnimTrigger = true } }
                        Timer { id: kbtimer; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
                        opacity: initAnimTrigger ? 1 : 0
                        transform: Translate { y: kbPill.initAnimTrigger ? 0 : 15; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        RowLayout { id: kbLayoutRow; anchors.centerIn: parent; spacing: 8
                            Text {
                                text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: UI.fontSize.md
                                color: barWindow.kbJustChanged ? mocha.green : (kbPill.isHovered ? mocha.text : mocha.overlay2)
                                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                text: barWindow.kbLayout; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
                                color: barWindow.kbJustChanged ? mocha.green : mocha.text
                                Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                        MouseArea {
                            id: kbMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                                // Poll after a short delay so the new layout is reflected
                                kbPollDelay.restart()
                            }
                        }
                        Timer {
                            id: kbPollDelay; interval: 200; repeat: false
                            onTriggered: kbPoller.running = true
                        }
                    }

                    // WiFi 
                    Rectangle {
                        id: wifiPill
                        property bool isHovered: wifiMouse.containsMouse
                        radius: 10; Layout.preferredHeight: sysLayout.pillHeight; 
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                        clip: true
                        
                        // Vibrant, guaranteed gradient contrast
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: barWindow.isWifiOn ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: mocha.blue }
                                GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                            }
                        }

                        property real targetWidth: wifiLayoutRow.implicitWidth + 24
                        Layout.preferredWidth: targetWidth
                        Behavior on targetWidth { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Cascading entrance animation
                        property bool initAnimTrigger: false
                        Component.onCompleted: { if (!barWindow.startupCascadeFinished) { wiftimer.start() } else { initAnimTrigger = true } }
                        Timer { id: wiftimer; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
                        opacity: initAnimTrigger ? 1 : 0
                        transform: Translate { y: wifiPill.initAnimTrigger ? 0 : 15; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        RowLayout { id: wifiLayoutRow; anchors.centerIn: parent; spacing: 8
                            Text { text: barWindow.wifiIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: UI.fontSize.md; color: barWindow.isWifiOn ? mocha.base : mocha.subtext0 }
                            Text { 
                                text: barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"; 
                                font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; 
                                color: barWindow.isWifiOn ? mocha.base : mocha.text; 
                                Layout.maximumWidth: 100; elide: Text.ElideRight 
                            }
                        }
                        MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hyprui-v2/popups/qs_manager.sh toggle network wifi`]) }
                    }

                    // Bluetooth
                    Rectangle {
                        id: btPill
                        property bool isHovered: btMouse.containsMouse
                        radius: 10; Layout.preferredHeight: sysLayout.pillHeight
                        clip: true
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                        
                        // Lavender gradient (distinct from WiFi blue) — shown when BT is enabled
                        Rectangle {
                            anchors.fill: parent; radius: 10
                            opacity: barWindow.isBtOn ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: mocha.lavender }
                                GradientStop { position: 1.0; color: Qt.lighter(mocha.lavender, 1.2) }
                            }
                        }

                        property real targetWidth: btLayoutRow.implicitWidth + 24
                        Layout.preferredWidth: targetWidth
                        Behavior on targetWidth { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Cascading entrance animation
                        property bool initAnimTrigger: false
                        Component.onCompleted: { if (!barWindow.startupCascadeFinished) { bttimer.start() } else { initAnimTrigger = true } }
                        Timer { id: bttimer; interval: 100; onTriggered: btPill.initAnimTrigger = true }
                        opacity: initAnimTrigger ? 1 : 0
                        transform: Translate { y: btPill.initAnimTrigger ? 0 : 15; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        RowLayout { id: btLayoutRow; anchors.centerIn: parent; spacing: 8
                            Text { text: barWindow.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: UI.fontSize.md; color: barWindow.isBtOn ? mocha.base : mocha.subtext0 }
                            Text {
                                text: barWindow.isBtOn ? (barWindow.btDevice !== "" ? barWindow.btDevice : "On") : "Off"
                                font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
                                color: barWindow.isBtOn ? mocha.base : mocha.text
                                Layout.maximumWidth: 100; elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: btMouse; hoverEnabled: true; anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton)
                                    Quickshell.execDetached(["blueberry"])
                                else
                                    Quickshell.execDetached(["/home/sohighman/.config/hypr/scripts/bluetooth-control.sh", "toggle"])
                                // bluetooth-control.sh has a `sleep 2` after starting the unit,
                                // so a single 400ms poll is too early. Re-poll repeatedly for ~5s.
                                btPollDelay.runCount = 0
                                btPollDelay.restart()
                            }
                        }
                        Timer {
                            id: btPollDelay
                            property int runCount: 0
                            interval: 700; repeat: true
                            onTriggered: {
                                btPoller.running = true
                                runCount += 1
                                if (runCount >= 7) { stop(); runCount = 0 }
                            }
                        }
                    }

                    // Volume
                    Rectangle {
                        id: volPill
                        property bool isHovered: volMouse.containsMouse
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                        radius: 10; Layout.preferredHeight: sysLayout.pillHeight;
                        clip: true

                        // New Dynamic Sound Background Gradient
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: barWindow.isSoundActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: mocha.peach }
                                GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                            }
                        }
                        
                        property real targetWidth: volLayoutRow.implicitWidth + 24
                        Layout.preferredWidth: targetWidth
                        Behavior on targetWidth { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Cascading entrance animation
                        property bool initAnimTrigger: false
                        Component.onCompleted: { if (!barWindow.startupCascadeFinished) { voltimer.start() } else { initAnimTrigger = true } }
                        Timer { id: voltimer; interval: 150; onTriggered: volPill.initAnimTrigger = true }
                        opacity: initAnimTrigger ? 1 : 0
                        transform: Translate { y: volPill.initAnimTrigger ? 0 : 15; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        RowLayout { id: volLayoutRow; anchors.centerIn: parent; spacing: 8
                            Text { 
                                text: barWindow.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: UI.fontSize.md;
                                color: barWindow.isSoundActive ? mocha.base : mocha.subtext0
                            }
                            Text { 
                                text: barWindow.volPercent; 
                                font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; 
                                color: barWindow.isSoundActive ? mocha.base : mocha.text; 
                            }
                        }
                        MouseArea { id: volMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["pavucontrol"]) }
                    }

                    // Night Light
                    Rectangle {
                        id: nlPill
                        property bool isHovered: nlMouse.containsMouse
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                        radius: 10; Layout.preferredHeight: sysLayout.pillHeight; Layout.preferredWidth: 44
                        clip: true

                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        property bool initAnimTrigger: false
                        Component.onCompleted: { if (!barWindow.startupCascadeFinished) { nltimer.start() } else { initAnimTrigger = true } }
                        Timer { id: nltimer; interval: 175; onTriggered: nlPill.initAnimTrigger = true }
                        opacity: initAnimTrigger ? 1 : 0
                        transform: Translate { y: nlPill.initAnimTrigger ? 0 : 15; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "󱩍"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                            color: nlPill.isHovered ? mocha.yellow : mocha.subtext0
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        MouseArea { id: nlMouse; hoverEnabled: true; anchors.fill: parent
                            onClicked: Quickshell.execDetached(["/home/sohighman/Documentos/Scripts/toggle_night_light.sh"])
                        }
                    }

                    // Battery
                    Item {
                        id:      battBox
                        Layout.preferredWidth: battLayout.implicitWidth
                        Layout.preferredHeight: UI.panelThickness
                        visible: UPower.displayDevice.isLaptopBattery

                        RowLayout {
                            id:      battLayout
                            anchors.fill: parent
                            spacing: 8

                            readonly property bool isCharging:
                                UPower.displayDevice.state === UPowerDeviceState.Charging ||
                                UPower.displayDevice.state === UPowerDeviceState.FullyCharged
                            readonly property real percentage: UPower.displayDevice.percentage * 100
                            
                            readonly property color battColor: isCharging
                                   ? HyprUITheme.active.green
                                   : (percentage <= 15 ? HyprUITheme.active.error
                                   : (percentage <= 30 ? HyprUITheme.secondary
                                   : HyprUITheme.active.green))

                            Text {
                                text: {
                                    if (battLayout.isCharging) return ""
                                    const icons = ["", "", "", "", ""]
                                    return icons[Math.min(Math.floor(battLayout.percentage / 20), 4)]
                                }
                                color: battLayout.battColor
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: UI.fontSize.md
                                font.bold: true
                            }

                            Text {
                                text: Math.round(battLayout.percentage) + "%"
                                color: battLayout.battColor
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: UI.fontSize.md
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hyprui-v2/popups/qs_manager.sh toggle battery`])

                            ToolTip {
                                id: battTip
                                visible: parent.containsMouse
                                delay: 800
                                text: (UPower.onBattery ? "⏳ Remaining: " : "⚡ Time to Full: ") +
                                      barWindow.formatSeconds(UPower.onBattery
                                          ? UPower.displayDevice.timeToEmpty
                                          : UPower.displayDevice.timeToFull)

                                background: Rectangle {
                                    color: Qt.color(HyprUITheme.active.background)
                                    radius: 14
                                    border.color: HyprUITheme.primary
                                    border.width: 1
                                    Rectangle {
                                        anchors.fill: parent; z: -1; radius: 8
                                        color: "black"; opacity: 0.25
                                        transform: Translate { x: 2; y: 2 }
                                    }
                                }
                                contentItem: Text {
                                    text: battTip.text
                                    color: Qt.color(HyprUITheme.active.text)
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

} // PanelWindow

} // Scope
