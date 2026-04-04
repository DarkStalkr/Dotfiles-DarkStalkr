import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

// ─── Dashboard Popup ──────────────────────────────────────────────────────────
// Opens below the top bar (centered). Visual language from CalendarPopup.qml:
//   · Ambient orbiting colour blobs behind everything
//   · Glass calendar card with rgba-white border
//   · Custom JS calendar grid (ListModel) with month navigation
//   · Time-of-day dynamic accent drawn from the active theme
//   · ALL font sizes derived from UI.fontSize — reactive to size presets

Scope {
    id: root
    required property ShellScreen screen

    readonly property bool isFocusedMonitor: Hypr.focusedMonitor?.name === screen.name
    readonly property bool visibleState: UI.dashboardVisible && isFocusedMonitor

    onVisibleStateChanged: { if (!visibleState) animTimer.restart() }

    // ── Time-of-day accent (uses active theme colours) ────────────────────────
    readonly property color timeAccent: {
        const h = root.now.getHours()
        if (h >= 5  && h < 12) return HyprUITheme.secondary          // morning
        if (h >= 12 && h < 17) return HyprUITheme.primary            // afternoon
        if (h >= 17 && h < 21) return HyprUITheme.active.error       // evening
        return HyprUITheme.primary                                    // night
    }

    property var  now:         new Date()
    property int  monthOffset: 0
    property string shownMonthLabel: ""
    ListModel { id: calModel }

    Timer {
        interval: 60000; running: root.visibleState; repeat: true
        onTriggered: root.now = new Date()
    }

    // Slow ambient orbit angle (90 s / full turn, like CalendarPopup)
    property real orbitAngle: 0
    NumberAnimation on orbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
    }

    function rebuildCalendar() {
        const base = new Date()
        base.setDate(1)
        base.setMonth(base.getMonth() + monthOffset)

        const yr  = base.getFullYear()
        const mo  = base.getMonth()
        const today     = new Date()
        const isRealMo  = (today.getMonth() === mo && today.getFullYear() === yr)
        const todayDate = today.getDate()

        shownMonthLabel = Qt.formatDateTime(base, "MMMM yyyy").toUpperCase()

        // Monday-first: 0=Mon … 6=Sun
        let firstWd = new Date(yr, mo, 1).getDay()
        firstWd = (firstWd === 0) ? 6 : firstWd - 1

        const daysInMo   = new Date(yr, mo + 1, 0).getDate()
        const daysInPrev = new Date(yr, mo,     0).getDate()

        calModel.clear()
        for (let i = firstWd - 1; i >= 0; i--)
            calModel.append({ d: (daysInPrev - i).toString(), inMonth: false, isToday: false })
        for (let i = 1; i <= daysInMo; i++)
            calModel.append({ d: i.toString(), inMonth: true, isToday: isRealMo && i === todayDate })
        const tail = 42 - calModel.count
        for (let i = 1; i <= tail; i++)
            calModel.append({ d: i.toString(), inMonth: false, isToday: false })
    }

    onMonthOffsetChanged: rebuildCalendar()

    // ── Panel geometry — scales with UI preset ────────────────────────────────
    readonly property int panelW: Math.round(260 + UI.panelThickness * 1.5)
    //  large  → 260+90  = 350
    //  medium → 260+69  = 329
    //  small  → 260+51  = 311

    PanelWindow {
        id: win
        screen: root.screen
        visible: visibleState || animTimer.running

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprui-dashboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Timer { id: animTimer; interval: 320 }

        MouseArea {
            anchors.fill: parent
            enabled: visibleState
            onClicked: UI.dashboardVisible = false
        }

        // ── Outer panel ───────────────────────────────────────────────────────
        Rectangle {
            id: panel

            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin:        UI.exclusiveZone + 6

            width:  root.panelW
            height: colMain.implicitHeight + 28

            // Slide-down + fade
            property real yOff: visibleState ? 0 : -12
            transform: Translate { y: panel.yOff }
            Behavior on yOff { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
            opacity: visibleState ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 260 } }

            radius: 14
            color:  HyprUITheme.active.background
            border.color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.30)
            border.width: 1

            MouseArea { anchors.fill: parent }     // block backdrop

            Component.onCompleted: root.rebuildCalendar()

            // ── Ambient blobs (behind content, inside panel) ──────────────────
            Item {
                anchors.fill: parent
                z: -1

                Rectangle {
                    width:  parent.width * 1.2;  height: width;  radius: width / 2
                    x: parent.width  / 2 - width  / 2 + Math.cos(root.orbitAngle * 1.3)  * (parent.width  * 0.25)
                    y: parent.height / 2 - height / 2 + Math.sin(root.orbitAngle * 1.3)  * (parent.height * 0.20)
                    color:   root.timeAccent
                    opacity: 0.06
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }

                Rectangle {
                    width:  parent.width * 0.9;  height: width;  radius: width / 2
                    x: parent.width  / 2 - width  / 2 + Math.sin(root.orbitAngle * -0.9) * (parent.width  * 0.22)
                    y: parent.height / 2 - height / 2 + Math.cos(root.orbitAngle * -0.9) * (parent.height * 0.18)
                    color:   HyprUITheme.primary
                    opacity: 0.05
                    Behavior on color { ColorAnimation { duration: 1500 } }
                }
            }

            // ── Content column ────────────────────────────────────────────────
            ColumnLayout {
                id: colMain
                anchors {
                    top: parent.top; left: parent.left; right: parent.right
                    topMargin: 16; leftMargin: 18; rightMargin: 18; bottomMargin: 12
                }
                spacing: 10

                // ── Clock ─────────────────────────────────────────────────────
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text:           Time.timeStr
                        color:          HyprUITheme.active.text
                        font.family:    "MesloLGS NF"
                        font.pixelSize: Math.round(UI.fontSize.lg * 2.6)
                        font.bold:      true
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text:           Time.format("dddd, MMMM d")
                        color:          root.timeAccent
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.sm
                        opacity:        0.85
                        Behavior on color { ColorAnimation { duration: 1200 } }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.18)
                }

                // ── Weather row ───────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text:           Weather.icon
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.lg
                        color:          root.timeAccent
                        Behavior on color { ColorAnimation { duration: 1200 } }
                    }
                    Text {
                        text:           Weather.description || "…"
                        color:          HyprUITheme.active.text
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.sm
                        opacity:        0.75
                        elide:          Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text:           Weather.temp
                        color:          HyprUITheme.active.text
                        font.family:    "MesloLGS NF"
                        font.pixelSize: UI.fontSize.sm
                        font.bold:      true
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.18)
                }

                // ── Glass calendar card ───────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height:  calCard.implicitHeight + 24
                    radius:  10
                    color:   Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    ColumnLayout {
                        id: calCard
                        anchors {
                            top: parent.top; left: parent.left; right: parent.right
                            topMargin: 12; leftMargin: 12; rightMargin: 12; bottomMargin: 12
                        }
                        spacing: 8

                        // Month navigation row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Prev month
                            Rectangle {
                                width: UI.wsSize * 0.85; height: width; radius: width / 2
                                color: prevMa.containsMouse
                                       ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family:    "MesloLGS NF"
                                    font.pixelSize: UI.fontSize.sm
                                    color:          HyprUITheme.active.text
                                }
                                MouseArea {
                                    id: prevMa; anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.monthOffset--
                                }
                            }

                            // Month label (centred)
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text:           root.shownMonthLabel
                                font.family:    "MesloLGS NF"
                                font.pixelSize: UI.fontSize.sm
                                font.bold:      true
                                color:          HyprUITheme.active.text
                            }

                            // Next month
                            Rectangle {
                                width: UI.wsSize * 0.85; height: width; radius: width / 2
                                color: nextMa.containsMouse
                                       ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family:    "MesloLGS NF"
                                    font.pixelSize: UI.fontSize.sm
                                    color:          HyprUITheme.active.text
                                }
                                MouseArea {
                                    id: nextMa; anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.monthOffset++
                                }
                            }
                        }

                        // Day-of-week abbreviations (Mo … Su)
                        RowLayout {
                            Layout.fillWidth: true
                            Repeater {
                                model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                Text {
                                    Layout.fillWidth: true
                                    text:               modelData
                                    font.family:        "MesloLGS NF"
                                    font.pixelSize:     Math.round(UI.fontSize.sm * 0.82)
                                    font.bold:          true
                                    color:              HyprUITheme.active.text
                                    opacity:            0.38
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Calendar grid (6 rows × 7 cols)
                        GridLayout {
                            Layout.fillWidth: true
                            columns:      7
                            rowSpacing:   4
                            columnSpacing: 2

                            Repeater {
                                model: calModel

                                Rectangle {
                                    readonly property bool hi: isToday
                                    Layout.fillWidth: true
                                    // Keep cells square-ish: width drives height
                                    implicitWidth:  Math.round((calCard.width - 24) / 7)
                                    implicitHeight: implicitWidth
                                    radius: Math.round(implicitWidth * 0.35)
                                    color: hi ? root.timeAccent
                                               : (dayHov.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                                    scale: dayHov.containsMouse ? 1.12 : 1.0

                                    Behavior on color { ColorAnimation { duration: 130 } }
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                    Text {
                                        anchors.centerIn: parent
                                        text:       d
                                        font.family: "MesloLGS NF"
                                        font.pixelSize: Math.round(UI.fontSize.sm * 0.88)
                                        font.bold:  hi
                                        color: hi ? HyprUITheme.active.background : HyprUITheme.active.text
                                        opacity: inMonth ? (hi ? 1.0 : 0.85) : 0.20
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea { id: dayHov; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }

                        // "Return to Today" — visible only when browsing other months
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: UI.fontSize.sm + 4
                            visible: root.monthOffset !== 0

                            Text {
                                anchors.centerIn: parent
                                text:           "Return to Today"
                                font.family:    "MesloLGS NF"
                                font.pixelSize: Math.round(UI.fontSize.sm * 0.88)
                                color:  retMa.containsMouse ? HyprUITheme.active.text : root.timeAccent
                                opacity: retMa.containsMouse ? 1.0 : 0.75
                                Behavior on color   { ColorAnimation  { duration: 130 } }
                                Behavior on opacity { NumberAnimation { duration: 130 } }
                            }
                            MouseArea {
                                id: retMa; anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.monthOffset = 0
                            }
                        }
                    }
                }
            }
        }
    }
}
