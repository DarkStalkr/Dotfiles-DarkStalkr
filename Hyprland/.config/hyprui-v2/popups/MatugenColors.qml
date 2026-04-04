import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: root

    // ─── Matugen data tracking ────────────────────────────────────────────────
    property bool _hasMatugen: false
    property string rawJson: ""

    // ─── Private matugen-sourced storage (Catppuccin Mocha fallback values) ───
    property color _mBase:     "#1e1e2e"
    property color _mMantle:   "#181825"
    property color _mCrust:    "#11111b"
    property color _mText:     "#cdd6f4"
    property color _mSubtext0: "#a6adc8"
    property color _mSubtext1: "#bac2de"
    property color _mSurface0: "#313244"
    property color _mSurface1: "#45475a"
    property color _mSurface2: "#585b70"
    property color _mOverlay0: "#6c7086"
    property color _mOverlay1: "#7f849c"
    property color _mOverlay2: "#9399b2"
    property color _mBlue:     "#89b4fa"
    property color _mSapphire: "#74c7ec"
    property color _mMauve:    "#cba6f7"
    property color _mGreen:    "#a6e3a1"
    property color _mRed:      "#f38ba8"
    property color _mPeach:    "#fab387"
    property color _mPink:     "#f5c2e7"
    property color _mYellow:   "#f9e2af"
    property color _mMaroon:   "#eba0ac"
    property color _mTeal:     "#94e2d5"

    // ─── Public API ───────────────────────────────────────────────────────────
    // Structural/accent: HyprUITheme when no matugen → reacts to HyprUITheme.cycle()
    // Palette-only colors (peach/pink/yellow/maroon/teal): no HyprUITheme mapping,
    // keep Catppuccin defaults unless matugen supplies them.
    readonly property color base:     _hasMatugen ? _mBase     : Qt.color(HyprUITheme.active.background)
    readonly property color mantle:   _hasMatugen ? _mMantle   : Qt.darker(Qt.color(HyprUITheme.active.background), 1.15)
    readonly property color crust:    _hasMatugen ? _mCrust    : Qt.darker(Qt.color(HyprUITheme.active.background), 1.3)
    readonly property color text:     _hasMatugen ? _mText     : Qt.color(HyprUITheme.active.text)
    readonly property color subtext0: _hasMatugen ? _mSubtext0 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.65)
    readonly property color subtext1: _hasMatugen ? _mSubtext1 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.80)
    readonly property color surface0: _hasMatugen ? _mSurface0 : Qt.color(HyprUITheme.active.surface)
    readonly property color surface1: _hasMatugen ? _mSurface1 : Qt.lighter(Qt.color(HyprUITheme.active.surface), 1.12)
    readonly property color surface2: _hasMatugen ? _mSurface2 : Qt.lighter(Qt.color(HyprUITheme.active.surface), 1.25)
    readonly property color overlay0: _hasMatugen ? _mOverlay0 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.30)
    readonly property color overlay1: _hasMatugen ? _mOverlay1 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.38)
    readonly property color overlay2: _hasMatugen ? _mOverlay2 : Qt.rgba(Qt.color(HyprUITheme.active.text).r, Qt.color(HyprUITheme.active.text).g, Qt.color(HyprUITheme.active.text).b, 0.45)
    readonly property color blue:     _hasMatugen ? _mBlue     : HyprUITheme.primary
    readonly property color mauve:    _hasMatugen ? _mMauve    : HyprUITheme.primary
    readonly property color sapphire: _hasMatugen ? _mSapphire : HyprUITheme.secondary
    readonly property color green:    _hasMatugen ? _mGreen    : Qt.color(HyprUITheme.active.green)
    readonly property color red:      _hasMatugen ? _mRed      : Qt.color(HyprUITheme.active.error)
    readonly property color peach:    _mPeach
    readonly property color pink:     _mPink
    readonly property color yellow:   _mYellow
    readonly property color maroon:   _mMaroon
    readonly property color teal:     _mTeal

    // ─── Matugen JSON reader ─────────────────────────────────────────────────
    Process {
        id: themeReader
        command: ["cat", "/tmp/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "" || txt === root.rawJson) return;
                root.rawJson = txt;
                try {
                    let c = JSON.parse(txt);
                    if (c.base)     root._mBase     = c.base;
                    if (c.mantle)   root._mMantle   = c.mantle;
                    if (c.crust)    root._mCrust    = c.crust;
                    if (c.text)     root._mText     = c.text;
                    if (c.subtext0) root._mSubtext0 = c.subtext0;
                    if (c.subtext1) root._mSubtext1 = c.subtext1;
                    if (c.surface0) root._mSurface0 = c.surface0;
                    if (c.surface1) root._mSurface1 = c.surface1;
                    if (c.surface2) root._mSurface2 = c.surface2;
                    if (c.overlay0) root._mOverlay0 = c.overlay0;
                    if (c.overlay1) root._mOverlay1 = c.overlay1;
                    if (c.overlay2) root._mOverlay2 = c.overlay2;
                    if (c.blue)     root._mBlue     = c.blue;
                    if (c.sapphire) root._mSapphire = c.sapphire;
                    if (c.mauve)    root._mMauve    = c.mauve;
                    if (c.green)    root._mGreen    = c.green;
                    if (c.red)      root._mRed      = c.red;
                    if (c.peach)    root._mPeach    = c.peach;
                    if (c.pink)     root._mPink     = c.pink;
                    if (c.yellow)   root._mYellow   = c.yellow;
                    if (c.maroon)   root._mMaroon   = c.maroon;
                    if (c.teal)     root._mTeal     = c.teal;
                    root._hasMatugen = true;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeReader.running = true
    }
}
