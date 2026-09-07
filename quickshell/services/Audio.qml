pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// PwObjectTracker is what makes a node's properties live — without the node
// sitting in a tracker, audio.volume/muted never bind.
Singleton {
    id: audio

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int percent: (audio.sink && audio.sink.audio)
                                   ? Math.round(audio.sink.audio.volume * 100) : 0
    readonly property bool muted: (audio.sink && audio.sink.audio)
                                  ? audio.sink.audio.muted : false
    readonly property int display: audio.percent
    property bool dragging: false   // knob scale only now

    function setVolume(pct) {
        if (!audio.sink || !audio.sink.audio) return
        audio.sink.audio.volume = Math.max(0, Math.min(100, Math.round(pct))) / 100
    }
    function nudge(delta) {
        audio.setVolume(audio.display + delta)
    }
    function toggleMute() {
        if (!audio.sink || !audio.sink.audio) return
        audio.sink.audio.muted = !audio.sink.audio.muted
    }
}
