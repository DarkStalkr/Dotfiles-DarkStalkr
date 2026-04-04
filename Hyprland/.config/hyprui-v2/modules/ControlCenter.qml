import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import "../services"
import "../components"

// ─── Compact Control Center Dropdown ─────────────────────────────────────────
// Triggered by 󰒓 icon in TopBar or keybind.
// ALL font sizes use UI.fontSize.sm/md/lg — fully reactive to size presets.
// Panel dimensions scale mildly with preset.

Scope {
    id: root
    required property ShellScreen screen

    readonly property bool isFocusedMonitor: Hypr.focusedMonitor?.name === screen.name
    readonly property bool visibleState: UI.controlCenterVisible && isFocusedMonitor

    onVisibleStateChanged: { if (!visibleState) animTimer.restart() }

    // ── Panel geometry — scales with UI preset ────────────────────────────────
    readonly property int panelW: Math.round(300 + UI.panelThickness * 0.85)
    //  large  → 300+51 = 351   medium → 300+39 = 339   small → 300+29 = 329
    readonly property int panelH: Math.round(390 + UI.panelThickness * 0.70)
    //  large  → 390+42 = 432   medium → 390+32 = 422   small → 390+24 = 414

    PanelWindow {
        id: win
        screen: root.screen
        visible: visibleState || animTimer.running

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprui-controlcenter"
        WlrLayershell.keyboardFocus: visibleState ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Timer { id: animTimer; interval: 320 }

        MouseArea {
            anchors.fill: parent
            enabled: visibleState
            onClicked: UI.controlCenterVisible = false
        }

        // ── Panel ─────────────────────────────────────────────────────────────
        Rectangle {
            id: panel

            anchors.top:         parent.top
            anchors.right:       parent.right
            anchors.topMargin:   UI.exclusiveZone + 6
            anchors.rightMargin: UI.panelMargin

            width:  root.panelW
            height: root.panelH

            property real yOff: visibleState ? 0 : -12
            transform: Translate { y: panel.yOff }
            Behavior on yOff { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
            opacity: visibleState ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 260 } }

            radius: 12
            color:  HyprUITheme.active.background
            border.color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.30)
            border.width: 1
            clip: true

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // ── Tab strip ─────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "󰒓", label: "System"        },
                            { icon: "󰝚", label: "Media"         },
                            { icon: "󰂚", label: "Notifications"  },
                            { icon: "󰺢", label: "Equalizer"      }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(UI.panelThickness * 0.60)
                            radius: 7
                            readonly property bool active: stack.currentIndex === index
                            color: active
                                   ? Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.18)
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text:           modelData.icon
                                font.family:    "MesloLGS NF"
                                font.pixelSize: UI.fontSize.md
                                color:  parent.active ? HyprUITheme.primary : HyprUITheme.active.text
                                opacity: parent.active ? 1.0 : 0.40
                                Behavior on color   { ColorAnimation  { duration: 180 } }
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: stack.currentIndex = index }
                        }
                    }

                    // Close button
                    Rectangle {
                        width: Math.round(UI.panelThickness * 0.60)
                        height: width; radius: 7; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family:    "MesloLGS NF"
                            font.pixelSize: UI.fontSize.sm
                            color:   HyprUITheme.active.text
                            opacity: 0.38
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: UI.controlCenterVisible = false
                            onEntered: parent.color = Qt.rgba(1, 1, 1, 0.07)
                            onExited:  parent.color = "transparent"
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Divider {}

                // ── Content stack ─────────────────────────────────────────────
                StackLayout {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: 0

                    // ── SYSTEM ────────────────────────────────────────────────
                    ColumnLayout {
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            CompactToggle {
                                label: "Wi-Fi"; icon: "󰖩"
                                active: Network.active !== null
                                onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"])
                            }
                            CompactToggle {
                                label: "Bluetooth"; icon: "󰂯"
                                active: Bluetooth.defaultAdapter?.enabled ?? false
                                onClicked: {
                                    if (Bluetooth.defaultAdapter)
                                        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                                }
                            }
                        }

                        Divider {}

                        CompactSlider {
                            label: "Volume"; icon: Audio.muted ? "󰝟" : "󰕾"
                            iconColor: Audio.muted ? HyprUITheme.active.error : HyprUITheme.primary
                            value: Audio.volume; accentColor: HyprUITheme.primary
                            onMoved: (v) => Audio.setVolume(v)
                        }
                        CompactSlider {
                            label: "Brightness"; icon: "󰃠"
                            iconColor: HyprUITheme.secondary
                            value: Brightness.brightness; accentColor: HyprUITheme.secondary
                            onMoved: (v) => Brightness.set(v)
                        }

                        Divider {}

                        // Battery
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: UPower.displayDevice.isLaptopBattery
                            Text {
                                text: UPower.displayDevice.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"
                                font.family:    "MesloLGS NF"
                                font.pixelSize: UI.fontSize.md
                                color: UPower.displayDevice.state === UPowerDeviceState.Charging
                                       ? HyprUITheme.active.green : HyprUITheme.active.text
                                opacity: 0.70
                            }
                            Text {
                                text: Math.round(UPower.displayDevice.percentage * 100) + "%  ·  " +
                                      (UPower.displayDevice.state === UPowerDeviceState.Charging
                                       ? "Charging" : "On battery")
                                color:          HyprUITheme.active.text
                                font.family:    "MesloLGS NF"
                                font.pixelSize: UI.fontSize.sm
                                font.bold:      true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: {
                                    const s = UPower.onBattery
                                              ? UPower.displayDevice.timeToEmpty
                                              : UPower.displayDevice.timeToFull
                                    return s > 0
                                           ? Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m"
                                           : ""
                                }
                                color:          HyprUITheme.active.text
                                font.family:    "MesloLGS NF"
                                font.pixelSize: UI.fontSize.sm
                                opacity:        0.45
                            }
                        }

                        Divider {}

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            SessionBtn { icon: "󰐥"; label: "Power Off"; btnColor: HyprUITheme.active.error;  onClicked: Quickshell.execDetached(["shutdown", "now"]) }
                            SessionBtn { icon: "󰑐"; label: "Reboot";    btnColor: HyprUITheme.secondary;      onClicked: Quickshell.execDetached(["reboot"]) }
                            SessionBtn { icon: "󰍃"; label: "Logout";    btnColor: HyprUITheme.primary;        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ── MEDIA ─────────────────────────────────────────────────
                    ColumnLayout {
                        spacing: 10

                        Repeater {
                            model: Mpris.players.values
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 10
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        width: Math.round(UI.panelThickness * 1.1)
                                        height: width; radius: 8; clip: true
                                        color: HyprUITheme.active.surface
                                        Image {
                                            anchors.fill: parent; source: modelData.trackArtUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !modelData.trackArtUrl
                                            text: "󰝚"; font.family: "MesloLGS NF"
                                            font.pixelSize: UI.fontSize.lg
                                            color: HyprUITheme.active.text; opacity: 0.22
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 3
                                        Text { text: modelData.trackTitle  || "No Title";       font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; font.bold: true;    color: HyprUITheme.active.text;  elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.trackArtist || "Unknown Artist"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm;                     color: HyprUITheme.active.text;  elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.55 }
                                        Text { text: modelData.identity    || "";               font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.88); color: HyprUITheme.primary;      elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.75; font.italic: true }
                                        RowLayout {
                                            spacing: 4; Layout.topMargin: 4
                                            MediaBtn { icon: "󰒮";  onClicked: modelData.previous() }
                                            MediaBtn { icon: modelData.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"; large: true; onClicked: modelData.togglePlaying() }
                                            MediaBtn { icon: "󰒭";  onClicked: modelData.next() }
                                        }
                                    }
                                }
                                Divider { visible: index < Mpris.players.values.length - 1 }
                            }
                        }

                        ColumnLayout {
                            visible: Mpris.players.values.length === 0
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                            Item { Layout.fillHeight: true }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "󰝛"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.lg * 2; color: HyprUITheme.active.text; opacity: 0.15 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "No active players"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; color: HyprUITheme.active.text; opacity: 0.35 }
                            Item { Layout.fillHeight: true }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ── NOTIFICATIONS ─────────────────────────────────────────
                    ColumnLayout {
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Notifications"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; font.bold: true; color: HyprUITheme.active.text; opacity: 0.55 }
                            Item { Layout.fillWidth: true }
                        }

                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: notifCol.implicitHeight; clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            ColumnLayout {
                                id: notifCol
                                width: parent.width; spacing: 7

                                Repeater {
                                    model: Notifications.notifications
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: nRow.implicitHeight + 16
                                        radius: 8; color: HyprUITheme.active.surface
                                        RowLayout {
                                            id: nRow
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                                            spacing: 8
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 2
                                                Text { text: modelData.appName || "Notification"; font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.88); font.bold: true; color: HyprUITheme.primary; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: modelData.summary || ""; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; font.bold: true; color: HyprUITheme.active.text; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { visible: (modelData.body || "") !== ""; text: modelData.body || ""; font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.88); color: HyprUITheme.active.text; opacity: 0.55; elide: Text.ElideRight; Layout.fillWidth: true }
                                            }
                                            Rectangle {
                                                width: UI.fontSize.sm + 8; height: width; radius: width / 2; color: "transparent"
                                                Text { anchors.centerIn: parent; text: "󰅖"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; color: HyprUITheme.active.text; opacity: 0.38 }
                                                MouseArea { anchors.fill: parent; onClicked: Notifications.remove(modelData.id) }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: Notifications.notifications.length === 0
                                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 16
                                    text: "No notifications"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; color: HyprUITheme.active.text; opacity: 0.30
                                }
                            }
                        }
                    }

                    // ── EQUALIZER ─────────────────────────────────────────────
                    ColumnLayout {
                        spacing: 8

                        // Preset chips
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: ["Flat","Bass","Treble","Vocal","Pop","Rock","Jazz","Classic"]
                                Rectangle {
                                    readonly property bool sel: Equalizer.currentPreset === modelData
                                    height: Math.round(UI.fontSize.sm * 1.8)
                                    width:  presetLabel.implicitWidth + 18
                                    radius: height / 2
                                    color: sel
                                           ? Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.22)
                                           : HyprUITheme.active.surface
                                    border.color: sel ? HyprUITheme.primary : "transparent"
                                    border.width: 1
                                    Text {
                                        id: presetLabel
                                        anchors.centerIn: parent
                                        text: modelData; font.family: "MesloLGS NF"
                                        font.pixelSize: Math.round(UI.fontSize.sm * 0.88)
                                        font.bold: sel
                                        color: sel ? HyprUITheme.primary : HyprUITheme.active.text
                                        opacity: sel ? 1.0 : 0.65
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Equalizer.applyPreset(modelData) }
                                }
                            }
                        }

                        Divider {}

                        // 10-band sliders
                        readonly property var bandLabels: ["32","80","200","500","1.25k","3k","8k","16k","20k","24k"]

                        Repeater {
                            model: 10
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text {
                                    text:           parent.parent.bandLabels[index]
                                    font.family:    "MesloLGS NF"
                                    font.pixelSize: Math.round(UI.fontSize.sm * 0.82)
                                    color:          HyprUITheme.active.text
                                    opacity:        0.50
                                    Layout.preferredWidth: Math.round(UI.fontSize.sm * 2.8)
                                    horizontalAlignment: Text.AlignRight
                                }
                                // Track
                                Rectangle {
                                    Layout.fillWidth: true; height: 6; radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    // Fill
                                    Rectangle {
                                        x: {
                                            const v = Equalizer.bands[index]
                                            return v >= 0
                                                   ? parent.width / 2
                                                   : parent.width / 2 * (1 + v / 12)
                                        }
                                        width: {
                                            const v = Equalizer.bands[index]
                                            return Math.abs(v) / 12 * parent.width / 2
                                        }
                                        height: parent.height; radius: 3
                                        color: HyprUITheme.primary
                                        Behavior on x     { NumberAnimation { duration: 120 } }
                                        Behavior on width { NumberAnimation { duration: 120 } }
                                    }
                                    // Centre tick
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1; height: parent.height; color: Qt.rgba(1,1,1,0.20) }
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed:         (e) => Equalizer.setBand(index, Math.round((e.x / width - 0.5) * 24))
                                        onPositionChanged: (e) => Equalizer.setBand(index, Math.round((e.x / width - 0.5) * 24))
                                    }
                                }
                                Text {
                                    text:           (Equalizer.bands[index] >= 0 ? "+" : "") + Equalizer.bands[index] + "dB"
                                    font.family:    "MesloLGS NF"
                                    font.pixelSize: Math.round(UI.fontSize.sm * 0.82)
                                    color:          HyprUITheme.active.text
                                    opacity:        0.50
                                    Layout.preferredWidth: Math.round(UI.fontSize.sm * 3.2)
                                }
                            }
                        }

                        // Apply button (visible only when pending)
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.round(UI.fontSize.md * 2)
                            radius: height / 2
                            visible: Equalizer.pending
                            color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.20)
                            border.color: HyprUITheme.primary; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "Apply EQ"; font.family: "MesloLGS NF"
                                font.pixelSize: UI.fontSize.sm; font.bold: true
                                color: HyprUITheme.primary
                            }
                            MouseArea { anchors.fill: parent; onClicked: Equalizer.apply() }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // ── Reusable inline components ────────────────────────────────────────────

    component Divider: Rectangle {
        Layout.fillWidth: true; height: 1
        color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.12)
    }

    component CompactToggle: Rectangle {
        property string label: ""; property string icon: ""
        property bool   active: false
        signal clicked()

        Layout.fillWidth: true
        height: Math.round(UI.panelThickness * 0.82)
        radius: 9
        color: active
               ? Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.22)
               : HyprUITheme.active.surface
        Behavior on color { ColorAnimation { duration: 180 } }

        ColumnLayout {
            anchors.centerIn: parent; spacing: 2
            Text { Layout.alignment: Qt.AlignHCenter; text: icon; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.md; color: active ? HyprUITheme.primary : HyprUITheme.active.text; Behavior on color { ColorAnimation { duration: 180 } } }
            Text { Layout.alignment: Qt.AlignHCenter; text: label; font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.85); color: HyprUITheme.active.text; opacity: active ? 0.90 : 0.50 }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component CompactSlider: ColumnLayout {
        property string label: ""; property string icon: ""; property color iconColor: HyprUITheme.active.text
        property real value: 0; property color accentColor: HyprUITheme.primary
        signal moved(real val)
        Layout.fillWidth: true; spacing: 5
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: icon; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.md; color: iconColor }
            Text { text: label; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; font.bold: true; opacity: 0.85; color: HyprUITheme.active.text; Layout.fillWidth: true }
            Text { text: Math.round(value * 100) + "%"; font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.88); color: HyprUITheme.active.text; opacity: 0.48 }
        }
        Rectangle {
            Layout.fillWidth: true; height: 6; radius: 3; color: Qt.rgba(1,1,1,0.08)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1.0, value)); height: parent.height; radius: 3; color: accentColor
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            }
            MouseArea {
                anchors.fill: parent
                onPressed:         (e) => moved(Math.max(0, Math.min(1.0, e.x / width)))
                onPositionChanged: (e) => moved(Math.max(0, Math.min(1.0, e.x / width)))
            }
        }
    }

    component SessionBtn: Rectangle {
        property string icon: ""; property string label: ""; property color btnColor: HyprUITheme.primary
        signal clicked()
        Layout.fillWidth: true
        height: Math.round(UI.panelThickness * 0.95)
        radius: 9; color: HyprUITheme.active.surface
        border.color: Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.28); border.width: 1
        ColumnLayout { anchors.centerIn: parent; spacing: 3
            Text { Layout.alignment: Qt.AlignHCenter; text: icon; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.md; color: btnColor }
            Text { Layout.alignment: Qt.AlignHCenter; text: label; font.family: "MesloLGS NF"; font.pixelSize: Math.round(UI.fontSize.sm * 0.85); font.bold: true; color: HyprUITheme.active.text }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked(); onEntered: parent.opacity = 0.72; onExited: parent.opacity = 1.0 }
    }

    component MediaBtn: Rectangle {
        property string icon: ""; property bool large: false
        signal clicked()
        width: large ? Math.round(UI.wsSize * 1.1) : Math.round(UI.wsSize * 0.85)
        height: width; radius: width / 2; color: "transparent"
        Text { anchors.centerIn: parent; text: icon; font.family: "MesloLGS NF"; font.pixelSize: large ? UI.fontSize.md : UI.fontSize.sm; color: large ? HyprUITheme.primary : HyprUITheme.active.text; opacity: large ? 1.0 : 0.65 }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked(); onEntered: parent.color = Qt.rgba(1,1,1,0.08); onExited: parent.color = "transparent" }
    }
}
