import QtQuick
import Quickshell
import "../services"

Item {
    id: root
    
    property string text: ""
    property int delay: 1000
    property string orientation: "top"
    property Item target: null
    
    implicitWidth: tooltipContent.width
    implicitHeight: tooltipContent.height
    
    visible: false
    z: 1000

    function updatePosition() {
        if (!target || !parent) return;
        
        // Map target coordinates to the coordinate system of the tooltip's parent
        var pos = target.mapToItem(parent, 0, 0);
        
        let targetX = 0;
        let targetY = 0;

        if (orientation === "top") {
            targetX = pos.x + (target.width - root.width) / 2;
            targetY = pos.y - root.height - 10;
        } else if (orientation === "bottom") {
            targetX = pos.x + (target.width - root.width) / 2;
            targetY = pos.y + target.height + 10;
        } else if (orientation === "left") {
            targetX = pos.x - root.width - 10;
            targetY = pos.y + (target.height - root.height) / 2;
        } else if (orientation === "right") {
            targetX = pos.x + target.width + 10;
            targetY = pos.y + (target.height - root.height) / 2;
        }
        
        root.x = targetX;
        root.y = targetY;
    }

    Component.onDestruction: showTimer.stop()

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: {
            root.updatePosition();
            root.visible = true;
            tooltipContent.opacity = 1;
        }
    }
    
    function requestShow() {
        if (!root.visible && !showTimer.running) {
            showTimer.restart();
        }
    }
    
    function requestHide() {
        showTimer.stop();
        tooltipContent.opacity = 0;
        root.visible = false;
    }

    Item {
        id: tooltipContent
        width: label.implicitWidth + 24
        height: label.implicitHeight + 16
        opacity: 0
        
        Behavior on opacity { 
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
        }

        Rectangle {
            anchors.fill: parent
            color: HyprUITheme.active.background
            radius: 10
            border.color: HyprUITheme.primary
            border.width: 1
            
            // Shadow
            Rectangle {
                anchors.fill: parent
                z: -1
                color: "black"
                opacity: 0.3
                radius: 10
                transform: Translate { x: 2; y: 2 }
            }
        }
        
        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: HyprUITheme.active.text
            font.family: "MesloLGS NF"
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
