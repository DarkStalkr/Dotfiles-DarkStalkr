import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: masterWindow
    title: "qs-master"
    
    // Wayland XDG-Shell windows cannot be manually positioned with x/y.
    // We let Hyprland handle placement (centered via window rules).
    
    //flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    
    // Hidden by default, only visible when a widget is active
    visible: currentActive !== "hidden"

    // Dynamic monitor tracking (still kept for layout math if needed, but not for window positioning)
    property int activeMx: 0
    property int activeMy: 0
    property int activeMw: 1920
    property int activeMh: 1080

    property string currentActive: "hidden" 
    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > /tmp/qs_active_widget"]);
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false 
    property bool isWallpaperTransition: false 

    // Dynamic duration to allow fast opening but keep morphing smooth
    property int morphDuration: 500

    property real animW: 1
    property real animH: 1
    
    // Monitor for external window destruction or closing
    onVisibleChanged: {
        if (!visible && currentActive !== "hidden") {
            currentActive = "hidden";
            widgetStack.clear();
        }
    }

    function handleIpc(rawCmd) {
        let parts = rawCmd.split(":");
        let cmd = parts[0];
        let arg = parts.length > 1 ? parts[1] : "";

        // Feed monitor dimensions dynamically
        if (parts.length >= 6) {
            masterWindow.activeMx = parseInt(parts[2]) || 0;
            masterWindow.activeMy = parseInt(parts[3]) || 0;
            masterWindow.activeMw = parseInt(parts[4]) || 1920;
            masterWindow.activeMh = parseInt(parts[5]) || 1080;
        }

        if (cmd === "close") {
            switchWidget("hidden", "");
        } else if (getLayout(cmd)) {
            delayedClear.stop();
            if (masterWindow.isVisible && masterWindow.currentActive === cmd) {
                switchWidget("hidden", "");
            } else {
                switchWidget(cmd, arg);
            }
        }
    }

    function getLayout(name) {
        let mw = masterWindow.activeMw;
        let mh = masterWindow.activeMh;

        let base = {
            "battery":   { w: 480,  h: 820, comp: "battery/BatteryPopup.qml" },
            "calendar":  { w: 760,  h: 874, comp: "calendar/CalendarPopup.qml" },
            "music":     { w: 700,  h: 620, comp: "music/MusicPopup.qml" },
            "network":   { w: 900,  h: 700, comp: "network/NetworkPopup.qml" },
            "stewart":   { w: 800,  h: 600, comp: "stewart/stewart.qml" },
            "wallpaper": { w: mw,   h: 650, comp: "wallpaper/WallpaperPicker.qml" },
            "monitors":  { w: 850,  h: 580, comp: "monitors/MonitorPopup.qml" },
            "focustime": { w: 900,  h: 720, comp: "focustime/FocusTimePopup.qml" },
            "hidden":    { w: 1,    h: 1,   comp: "" }
        };

        return base[name] || null;
    }

    // INNER ANIMATED CONTAINER
    Item {
        anchors.centerIn: parent
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true 

        // Morphing animations for size only (position is handled by WM centering)
        Behavior on width { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: masterWindow.isWallpaperTransition ? 150 : (masterWindow.morphDuration === 500 ? 300 : 200); easing.type: Easing.InOutSine } }

        // INNER FIXED SIZE WIDGET CONTENT
        Item {
            anchors.centerIn: parent
            width: masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive) ? getLayout(masterWindow.currentActive).w : 1
            height: masterWindow.currentActive !== "hidden" && getLayout(masterWindow.currentActive) ? getLayout(masterWindow.currentActive).h : 1

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true
                
                Keys.onEscapePressed: {
                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hyprui-v2/popups/qs_manager.sh", "close"])
                    event.accepted = true
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 300; easing.type: Easing.InExpo }
                        NumberAnimation { property: "scale"; from: 1.0; to: 1.02; duration: 300; easing.type: Easing.InExpo }
                    }
                }
            }
        }
    }

    function switchWidget(newWidget, arg) {
        let involvesWallpaper = (newWidget === "wallpaper" || currentActive === "wallpaper");
        masterWindow.isWallpaperTransition = involvesWallpaper;

        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && getLayout(currentActive)) {
                masterWindow.morphDuration = 250; 
                masterWindow.disableMorph = false;
                
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;
                
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 250; 
                masterWindow.disableMorph = false;
                let t = getLayout(newWidget);

                masterWindow.animW = 1;
                masterWindow.animH = 1;

                masterWindow.implicitWidth = t.w;
                masterWindow.implicitHeight = t.h;

                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start();
                
            } else {
                masterWindow.morphDuration = 500; 
                if (involvesWallpaper) {
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false; 
                    teleportFadeOutTimer.newWidget = newWidget;
                    teleportFadeOutTimer.newArg = arg;
                    teleportFadeOutTimer.start();
                } else {
                    masterWindow.disableMorph = false;
                    executeSwitch(newWidget, arg, false);
                }
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 50
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg, false)
    }

    Timer {
        id: teleportFadeOutTimer
        interval: 150 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            let t = getLayout(newWidget);

            masterWindow.currentActive = newWidget;
            masterWindow.activeArg = newArg;

            masterWindow.animW = t.w;
            masterWindow.animH = t.h;

            masterWindow.implicitWidth = t.w;
            masterWindow.implicitHeight = t.h;

            let props = newWidget === "wallpaper" ? { "widgetArg": newArg } : {};
            widgetStack.replace(t.comp, props, StackView.Immediate);

            teleportFadeInTimer.newWidget = newWidget;
            teleportFadeInTimer.newArg = newArg;
            teleportFadeInTimer.start();
        }
    }

    Timer {
        id: teleportFadeInTimer
        interval: 50 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            masterWindow.isVisible = true; 
            if (newWidget !== "wallpaper") resetMorphTimer.start();
        }
    }

    Timer {
        id: resetMorphTimer
        interval: masterWindow.morphDuration 
        onTriggered: masterWindow.disableMorph = false
    }

    function executeSwitch(newWidget, arg, immediate) {
        let t = getLayout(newWidget);

        // Set window dimensions BEFORE making it visible, so the compositor
        // receives the correct size at the moment the surface is mapped.
        masterWindow.implicitWidth = t.w;
        masterWindow.implicitHeight = t.h;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;

        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        masterWindow.isVisible = true;

        let props = newWidget === "wallpaper" ? { "widgetArg": arg } : {};

        if (immediate) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, props);
        }
    }

    Timer {
        id: delayedClear
        interval: masterWindow.isWallpaperTransition ? 150 : masterWindow.morphDuration 
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;

            masterWindow.implicitWidth = 1;
            masterWindow.implicitHeight = 1;
        }
    }
}
