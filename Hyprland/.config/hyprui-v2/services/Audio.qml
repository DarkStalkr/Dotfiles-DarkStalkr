pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../config"

Singleton {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(node => !node.isStream && node.isSink)
    readonly property var sources: Pipewire.nodes.values.filter(node => !node.isStream && node.audio && !node.isSink)
    readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream && node.audio)

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Track all nodes so that sink/source switches work reliably
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: {
        const v = sink?.audio?.volume;
        return (v != null && !isNaN(v)) ? v : 0;
    }

    // Emitted when the default sink itself changes (not just volume)
    signal defaultSinkChanged()
    onSinkChanged: defaultSinkChanged()

    function increaseVolume(): void {
        setVolume(volume + Config.services.audioIncrement);
    }

    function decreaseVolume(): void {
        setVolume(volume - Config.services.audioIncrement);
    }

    function setVolume(newVolume: real): void {
        const s = Pipewire.defaultAudioSink;
        if (s?.ready && s?.audio) {
            s.audio.muted = false;
            s.audio.volume = Math.max(0, Math.min(1.5, newVolume));
        }
    }

    function toggleMute(): void {
        const s = Pipewire.defaultAudioSink;
        if (s?.audio) s.audio.muted = !s.audio.muted;
    }
}
