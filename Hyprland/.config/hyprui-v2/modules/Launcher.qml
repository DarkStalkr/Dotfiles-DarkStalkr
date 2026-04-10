import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../components"

Scope {
    id: root
    required property ShellScreen screen
    property int fontSizeBase: 14

    // Only show on the focused monitor to avoid multi-focus issues
    readonly property bool isFocusedMonitor: Hyprland.focusedMonitor?.name === screen?.name
    readonly property bool visibleState: UI.launcherVisible && isFocusedMonitor

    onVisibleStateChanged: {
        if (visibleState) {
            searchInput.text = "";
            searchInput.forceActiveFocus();
        }
    }

    property string searchQuery: ""
    property var filteredApps: []
    property int selectedIndex: 0

    function updateFilter() {
        filteredApps = Apps.search(searchQuery).slice(0, 8);
        if (selectedIndex >= filteredApps.length) selectedIndex = Math.max(0, filteredApps.length - 1);
    }

    onSearchQueryChanged: updateFilter()

    PanelWindow {
        id: win
        screen: root.screen
        visible: visibleState

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprui-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.4
            MouseArea { anchors.fill: parent; onClicked: UI.launcherVisible = false }
        }

        // ─── Launcher container ───────────────────────────────────────────
        // Visual port of the previous wofi config (~/.config/wofi/style.css):
        //   • base background, ~2.5px primary (was lavender) border, tiny radius
        //   • outer-box / inner-box paddings collapsed into a single ColumnLayout
        //   • input has 4px outline in primary (was hardcoded red)
        //   • selected entry: 2px primary border + secondary text (was mauve)
        // All colors come from HyprUITheme so theme cycling re-themes the
        // launcher in lockstep with the rest of the shell.
        Rectangle {
            id: container
            anchors.centerIn: parent

            // Wofi-style dynamic sizing:
            //   width  = 50% of screen logical width
            //   height = min(40% of screen, content height) — shrinks when
            //            few results so the popup doesn't dwarf 1-2 items.
            // appListView.contentHeight grows with the filtered list; the
            // Math.min cap matches wofi's `--height 40%` behaviour.
            width: Math.round(win.width * 0.5)
            height: {
                const maxH = Math.round(win.height * 0.4)
                // 30 outer margins + 44 input + 10 spacing + 16 inner-box margins
                const chrome = 100
                const needed = chrome + Math.max(appListView.contentHeight, 60)
                return Math.min(maxH, needed)
            }

            // Wofi used `border-radius: 0.1em` ≈ ~2px — keep it crisp.
            radius: 1
            color: HyprUITheme.active.background
            // 0.16em ≈ 2.5px lavender border in wofi
            //border.color: HyprUITheme.active.secondary
            //border.width: Math.max(1, Math.round(0.16 * root.fontSizeBase))

            opacity: visibleState ? 1.0 : 0.0
            scale: visibleState ? 1.0 : 0.95

            Behavior on opacity { NumberAnimation { duration: 500 } }
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

            ColumnLayout {
                // wofi outer-box: 5px margin + 10px padding ≈ 15px combined
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // ── Input ──────────────────────────────────────────────────
                // wofi input: 5px 20px margin, 10px padding. Border kept at 1px
                // (thin) per user request — focus state is conveyed by colour,
                // not thickness, so the box never visibly resizes.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 44
                    radius: 4
                    color: HyprUITheme.active.background
                    border.width: 1
                    border.color: searchInput.activeFocus
                        ? HyprUITheme.primary
                        : Qt.rgba(HyprUITheme.primary.r, HyprUITheme.primary.g, HyprUITheme.primary.b, 0.35)

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Magnifier glyph — themed via HyprUITheme.primary so it
                    // re-tints on every theme cycle.
                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 18
                        color: HyprUITheme.secondary
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        // Leave room for the magnifier on the left.
                        anchors.leftMargin: 36
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: HyprUITheme.active.text
                        // wofi: Inconsolata Nerd Font 14px
                        font.family: "Inconsolata Nerd Font"
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        focus: true
                        clip: true

                        onTextChanged: root.searchQuery = text

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) UI.launcherVisible = false;
                            if (event.key === Qt.Key_Down) root.selectedIndex = (root.selectedIndex + 1) % Math.max(1, root.filteredApps.length);
                            if (event.key === Qt.Key_Up) root.selectedIndex = (root.selectedIndex - 1 + root.filteredApps.length) % Math.max(1, root.filteredApps.length);
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.filteredApps[root.selectedIndex]) {
                                    Apps.launch(root.filteredApps[root.selectedIndex]);
                                    UI.launcherVisible = false;
                                }
                            }
                        }
                    }
                }

                // ── Inner-box / scrolling app list ─────────────────────────
                // wofi inner-box: 5px margin + 10px padding inside outer-box.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 5
                    radius: 4
                    color: HyprUITheme.active.background
                    border.width: 0

                    ListView {
                        id: appListView
                        anchors.fill: parent
                        anchors.margins: 8
                        model: root.filteredApps
                        spacing: 4
                        clip: true

                        delegate: Rectangle {
                            id: appItem
                            width: appListView.width
                            height: 42
                            radius: 4
                            color: HyprUITheme.active.background
                            // wofi: 0.11em (~1.8px) lavender border on selected
                            border.color: index === root.selectedIndex ? HyprUITheme.primary : "transparent"
                            border.width: 2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Image {
                                    source: Quickshell.iconPath(modelData.icon, "image-missing")
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    // wofi: #entry:selected #text → mauve.
                                    // Map to HyprUITheme.secondary so it tracks themes.
                                    color: index === root.selectedIndex
                                        ? HyprUITheme.secondary
                                        : HyprUITheme.active.text
                                    font.family: "Inconsolata Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: index === root.selectedIndex
                                    elide: Text.ElideRight
                                    // Crisper glyphs on fractional-scaled monitors
                                    // (e.g. Hyprland scale: 2.00) — matches wofi/GTK.
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        Apps.launch(modelData);
                                        UI.launcherVisible = false;
                                    } else {
                                        UI.pinApp(modelData.id);
                                    }
                                }
                                hoverEnabled: true
                                onEntered: {
                                    root.selectedIndex = index;
                                    launchTooltip.requestShow();
                                }
                                onExited: launchTooltip.requestHide()
                            }

                            Tooltip {
                                id: launchTooltip
                                text: "Left: Launch | Right: Pin"
                                target: appItem
                            }
                        }
                    }
                }
            }
        }
    }
}
