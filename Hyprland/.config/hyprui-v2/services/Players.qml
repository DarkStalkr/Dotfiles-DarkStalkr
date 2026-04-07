pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQml

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values

    // QML bindings can't see property reads inside Array.find() callbacks, so a
    // binding over `list` alone never re-runs when an existing player flips
    // Play↔Pause — only when a player is added/removed. We bump `_tick` from a
    // Connections attached to every player below, and reference it inside the
    // `active` getter so QML knows to recompute on every status change.
    property int _tick: 0

    Instantiator {
        model: root.list
        delegate: QtObject {
            required property var modelData
            readonly property var conn: Connections {
                target: modelData
                // MprisPlayer's signal is playbackStateChanged — `playbackStatus`
                // does not exist on Quickshell's MprisPlayer (warned at runtime).
                function onPlaybackStateChanged() { root._tick++ }
                function onTrackTitleChanged()    { root._tick++ }
            }
        }
    }

    readonly property MprisPlayer active: {
        void _tick; // dependency marker — do not remove
        if (props.manualActiveIdentity) {
            const found = list.find(p => p.identity === props.manualActiveIdentity);
            if (found) return found;
        }
        // Prefer a player that is actively Playing.
        const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing);
        if (playing) return playing;
        // Otherwise prefer a Paused player that still has a track loaded —
        // avoids surfacing a "blank" Firefox tab over a paused-but-loaded mpv.
        const pausedWithTrack = list.find(p =>
            p.playbackState === MprisPlaybackState.Paused && (p.trackTitle ?? "") !== "");
        if (pausedWithTrack) return pausedWithTrack;
        return list[0] ?? null;
    }

    PersistentProperties {
        id: props
        property string manualActiveIdentity: ""
        reloadableId: "players"
    }

    IpcHandler {
        target: "mpris"

        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => p.identity).join("\n");
        }

        function togglePlaying(): void {
            root.active?.togglePlaying();
        }

        function previous(): void {
            root.active?.previous();
        }

        function next(): void {
            root.active?.next();
        }

        function stop(): void {
            root.active?.stop();
        }
    }
}
