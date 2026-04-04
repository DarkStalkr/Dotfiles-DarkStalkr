import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

// ─── Wallpaper Picker ─────────────────────────────────────────────────────────
// Triggered from the SideBar  icon.
// Scans UserPaths.wallpaperDir for images, shows a scrollable thumbnail grid.
// Click a thumbnail → set wallpaper via swww, optionally reload matugen colors.
// Glassmorphic style + reactive to UI size presets.

Scope {
    id: root
    required property ShellScreen screen

    readonly property bool isFocusedMonitor: Hypr.focusedMonitor?.name === screen.name
    readonly property bool visibleState: UI.wallpaperPickerVisible && isFocusedMonitor

    onVisibleStateChanged: {
        if (visibleState) scanWallpapers()
        else animTimer.restart()
    }

    // ── Wallpaper scanning ────────────────────────────────────────────────────
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string activeWallpaper: ""

    ListModel { id: wpModel }

    function scanWallpapers() {
        wpModel.clear()
        scanProc.running = true
    }

    Process {
        id: scanProc
        command: [
            "bash", "-c",
            "find '" + root.wallpaperDir + "' -maxdepth 2 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "2>/dev/null | sort | head -200"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0)
                lines.forEach(path => wpModel.append({ filePath: path }))
            }
        }
    }

    // Apply wallpaper via swww
    function applyWallpaper(path) {
        root.activeWallpaper = path
        applyProc.command = [
            "bash", "-c",
            "swww img '" + path + "' --transition-type fade --transition-duration 1 " +
            "&& (command -v matugen &>/dev/null && matugen image '" + path + "' || true)"
        ]
        applyProc.running = true
    }

    Process { id: applyProc; command: []; running: false }

    // ── Panel geometry (scales with UI preset) ────────────────────────────────
    readonly property int panelW: Math.min(
        Math.round(screen.width  - UI.exclusiveZone - UI.panelMargin * 4),
        Math.round(180 + UI.panelThickness * 8.5)
    )
    //  large  ~690  medium ~571  small ~459   (capped at screen width - sidebar)
    readonly property int panelH: Math.round(screen.height * 0.72)
    readonly property int thumbW: Math.round(root.panelW / 4 - 10)
    readonly property int thumbH: Math.round(root.thumbW * 0.58)

    PanelWindow {
        id: win
        screen: root.screen
        visible: visibleState || animTimer.running

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprui-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Timer { id: animTimer; interval: 320 }

        MouseArea {
            anchors.fill: parent
            enabled: visibleState
            onClicked: UI.wallpaperPickerVisible = false
        }

        // ── Panel ─────────────────────────────────────────────────────────────
        Rectangle {
            id: panel

            // Anchored left-center: beside the SideBar, vertically centred
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin:     UI.exclusiveZone + 6

            width:  root.panelW
            height: root.panelH

            property real yOff: visibleState ? 0 : -12
            transform: Translate { y: panel.yOff }
            Behavior on yOff { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
            opacity: visibleState ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 260 } }

            radius: 14
            color:  HyprUITheme.active.background
            border.color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.30)
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 14
                spacing: 10

                // ── Header ────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Text {
                        text: "󰸉"
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.lg
                        color:          HyprUITheme.primary
                    }
                    Text {
                        text: "Wallpapers"
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.md
                        font.bold:      true
                        color:          HyprUITheme.active.text
                        Layout.fillWidth: true
                    }
                    Text {
                        text: wpModel.count + " found"
                        font.family:    "MesloLGS NF"
                        font.pixelSize: Math.round(UI.fontSize.sm * 0.88)
                        color:          HyprUITheme.active.text
                        opacity:        0.42
                    }
                    // Refresh button
                    Rectangle {
                        width: Math.round(UI.fontSize.md * 2); height: width; radius: width / 2; color: "transparent"
                        Text { anchors.centerIn: parent; text: "󰑐"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; color: HyprUITheme.active.text; opacity: 0.55 }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.scanWallpapers(); onEntered: parent.color = Qt.rgba(1,1,1,0.08); onExited: parent.color = "transparent" }
                    }
                    // Close
                    Rectangle {
                        width: Math.round(UI.fontSize.md * 2); height: width; radius: width / 2; color: "transparent"
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: "MesloLGS NF"; font.pixelSize: UI.fontSize.sm; color: HyprUITheme.active.text; opacity: 0.42 }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: UI.wallpaperPickerVisible = false; onEntered: parent.color = Qt.rgba(1,1,1,0.08); onExited: parent.color = "transparent" }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.18)
                }

                // ── Active wallpaper preview ──────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: root.activeWallpaper !== "" ? Math.round(root.thumbH * 1.4) : 0
                    visible: root.activeWallpaper !== ""
                    radius:  9; clip: true
                    color:   HyprUITheme.active.surface
                    border.color: HyprUITheme.primary; border.width: 1

                    Image {
                        anchors.fill: parent
                        source:   root.activeWallpaper ? ("file://" + root.activeWallpaper) : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                    Text {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                        text:           root.activeWallpaper.split("/").pop()
                        font.family:    "MesloLGS NF"
                        font.pixelSize: Math.round(UI.fontSize.sm * 0.85)
                        color:          "white"
                        opacity:        0.80
                        style:          Text.Outline; styleColor: "#80000000"
                    }
                }

                // ── Thumbnail grid ────────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    // Empty state
                    Text {
                        visible: wpModel.count === 0 && !scanProc.running
                        anchors.centerIn: parent
                        text:           "No wallpapers found\n" + root.wallpaperDir
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.sm
                        color:          HyprUITheme.active.text
                        opacity:        0.35
                        horizontalAlignment: Text.AlignHCenter
                    }

                    GridLayout {
                        width: parent.width
                        columns:      4
                        columnSpacing: 8
                        rowSpacing:    8

                        Repeater {
                            model: wpModel

                            Rectangle {
                                Layout.fillWidth: true
                                implicitWidth:  root.thumbW
                                implicitHeight: root.thumbH
                                radius: 8; clip: true
                                color:  HyprUITheme.active.surface

                                readonly property bool isActive: root.activeWallpaper === filePath
                                border.color: isActive ? HyprUITheme.primary : (ma.containsMouse ? Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.50) : "transparent")
                                border.width: isActive ? 2 : (ma.containsMouse ? 1 : 0)

                                scale: ma.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                                Image {
                                    anchors.fill: parent
                                    source:   "file://" + filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // Loading indicator
                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius
                                    visible: parent.children[0].status !== Image.Ready
                                    color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰸉"; font.family: "MesloLGS NF"
                                        font.pixelSize: UI.fontSize.lg
                                        color: HyprUITheme.active.text; opacity: 0.18
                                    }
                                }

                                MouseArea {
                                    id: ma; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyWallpaper(filePath)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
