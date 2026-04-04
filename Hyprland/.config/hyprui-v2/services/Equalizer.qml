pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ─── Equalizer Service ────────────────────────────────────────────────────────
// Wraps scripts/equalizer.sh which drives EasyEffects.
// Properties update by polling the state file every 2 s.
// Call setBand / applyPreset / apply from the UI.

Singleton {
    id: root

    // Absolute path resolved from this file's location in services/
    readonly property string script: Qt.resolvedUrl("../scripts/equalizer.sh")
                                        .toString().replace(/^file:\/\//, "")

    property string currentPreset: "Flat"
    property var    bands:         [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool   pending:       false

    // ── Public API ────────────────────────────────────────────────────────────

    function setBand(idx, dB) {
        const clamped = Math.max(-12, Math.min(12, Math.round(dB)))
        // Optimistic local update so UI responds instantly
        let b = [...bands]; b[idx] = clamped; bands = b
        pending = true; currentPreset = "Custom"
        _run(["bash", script, "set_band", String(idx + 1), String(clamped)])
    }

    function apply() {
        pending = false
        _run(["bash", script, "apply"])
    }

    function applyPreset(name) {
        currentPreset = name
        pending = false
        _run(["bash", script, "preset", name])
        // Refresh after a short delay so bands reflect the loaded preset
        Qt.callLater(() => { pollTimer.restart(); _refresh() })
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    function _run(cmd) {
        runProc.command = cmd
        runProc.running = true
    }

    function _refresh() {
        refreshProc.running = true
    }

    Process {
        id: runProc
        command: []
        running: false
    }

    Process {
        id: refreshProc
        command: ["bash", root.script, "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim()
                if (!txt) return
                try {
                    const s = JSON.parse(txt)
                    const nb = []
                    for (let i = 1; i <= 10; i++) nb.push(Number(s["b" + i]) || 0)
                    root.bands         = nb
                    root.currentPreset = s.preset  || "Flat"
                    root.pending       = s.pending || false
                } catch (e) { console.warn("Equalizer: parse error:", e) }
            }
        }
    }

    // Poll every 2 s for external changes (e.g. another app changed the preset)
    Timer {
        id: pollTimer
        interval: 2000; running: true; repeat: true
        onTriggered: root._refresh()
    }

    Component.onCompleted: root._refresh()
}
