pragma ComponentBehavior: Bound

// Put this beside your existing lock-screen QML file.
// This component displays cameras only. Keep the existing WlSessionLock,
// password entry, PAM authentication, and display-power code unchanged.
// Requires Qt 6.9+ (VideoOutput.clearOutput).
// Recreating players is a mitigation, not a hard process/GPU memory limit.
// Use low-resolution camera substreams: resizing a VideoOutput does NOT
// reduce the resolution decoded by MediaPlayer.
import QtQuick
import QtMultimedia

Item {
    id: root

    property string frigateHost: "10.0.1.12"
    property int rtspPort: 8554
    // Prefer low-resolution go2rtc substream aliases if you have configured them.
    // These defaults preserve the stream names in your original configuration.
    property var streamNames: ["rtsp_cam", "rtsp_cam2", "rtsp_cam3", "rtsp_cam4"]
    property bool streamingEnabled: true
    property int playerLifetimeMs: 5 * 60 * 1000
    property int maxConsecutiveFailures: 6
    readonly property bool shouldPlay: streamingEnabled && visible
    // Never create more than four decoders, even if a larger model is supplied.
    readonly property var displayedStreams: Array.isArray(streamNames) ? streamNames.slice(0, 4) : []

    Grid {
        id: grid
        anchors.fill: parent
        columns: 2
        spacing: 4
        readonly property int rowCount: Math.max(1, Math.ceil(root.displayedStreams.length / columns))

        Repeater {
            model: root.displayedStreams

            delegate: Rectangle {
                id: tile
                required property string modelData
                required property int index
                objectName: "cameraTile_" + index

                width: Math.max(0, (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns)
                height: Math.max(0, (grid.height - grid.spacing * (grid.rowCount - 1)) / grid.rowCount)
                color: "black"
                clip: true

                readonly property string streamUrl: "rtsp://" + root.frigateHost
                    + ":" + root.rtspPort + "/" + modelData
                property int retryDelayMs: 2000
                property int pendingDelayMs: 1500
                property string statusText: "Connecting..."
                property bool destroying: false
                property int consecutiveFailures: 0
                property bool retryExhausted: false
                property bool pauseAfterStop: false

                function requestRestart(delayMs, message) {
                    if (destroying || !root.shouldPlay || retryExhausted || restartRequest.running || reconnect.running)
                        return
                    pendingDelayMs = delayMs
                    statusText = message
                    // Defer unloading until after the MediaPlayer signal handler returns.
                    restartRequest.start()
                }

                function requestRetry(message) {
                    if (destroying || !root.shouldPlay || retryExhausted || restartRequest.running || reconnect.running)
                        return
                    console.warn("Camera " + modelData + ": " + message)
                    consecutiveFailures += 1
                    pauseAfterStop = consecutiveFailures >= Math.max(1, root.maxConsecutiveFailures)
                    requestRestart(retryDelayMs, pauseAfterStop
                        ? "Unavailable — retry limit reached\nUnlock and lock again to retry"
                        : "Reconnecting...")
                    retryDelayMs = Math.min(30000, retryDelayMs * 2)
                }

                Timer {
                    id: restartRequest
                    interval: 1
                    repeat: false
                    onTriggered: {
                        if (!root.shouldPlay || tile.destroying) return
                        // Explicit cleanup occurs while the loaded item is alive.
                        if (decoderLoader.item)
                            decoderLoader.item.shutdown()
                        if (tile.pauseAfterStop) {
                            tile.retryExhausted = true
                            return
                        }
                        reconnect.interval = tile.pendingDelayMs
                        reconnect.start()
                    }
                }

                // While this runs, Loader.active is false: the entire decoder
                // AND its VideoOutput are destroyed, rather than just paused.
                Timer {
                    id: reconnect
                    interval: 1500
                    repeat: false
                    onTriggered: tile.statusText = "Connecting..."
                }

                Connections {
                    target: root
                    function onShouldPlayChanged() {
                        if (!root.shouldPlay) {
                            restartRequest.stop()
                            reconnect.stop()
                            tile.retryDelayMs = 2000
                            tile.consecutiveFailures = 0
                            tile.retryExhausted = false
                            tile.pauseAfterStop = false
                            tile.statusText = "Connecting..."
                        }
                    }
                }

                Loader {
                    id: decoderLoader
                    anchors.fill: parent
                    active: root.shouldPlay && !tile.retryExhausted && !reconnect.running

                    sourceComponent: Component {
                        Item {
                            id: playback
                            objectName: "cameraPlayback_" + tile.index
                            property bool receivedFrame: false
                            readonly property bool playing: player.playbackState === MediaPlayer.PlayingState

                            function shutdown() {
                                if (player.closing) return
                                player.closing = true
                                frameWatchdog.stop()
                                healthyPlayback.stop()
                                recyclePlayer.stop()
                                player.stop()
                                player.source = ""
                                player.videoOutput = null
                                output.clearOutput()
                            }

                            VideoOutput {
                                id: output
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectFit
                                endOfStreamPolicy: VideoOutput.ClearOutput
                            }

                            // No AudioOutput: the cameras remain silent.
                            MediaPlayer {
                                id: player
                                objectName: "cameraPlayer_" + tile.index
                                property bool closing: false
                                source: tile.streamUrl
                                videoOutput: output
                                Component.onCompleted: play()

                                onErrorOccurred: (error, errorString) => {
                                    if (!closing)
                                        tile.requestRetry(errorString)
                                }

                                onMediaStatusChanged: {
                                    if (!closing && mediaStatus === MediaPlayer.EndOfMedia)
                                        tile.requestRetry("Stream ended")
                                }

                                // Cleanup here touches this MediaPlayer only;
                                // sibling/parent destruction order is unspecified.
                                Component.onDestruction: {
                                    closing = true
                                    stop()
                                    source = ""
                                    videoOutput = null
                                }
                            }

                            Connections {
                                target: output.videoSink
                                // Do not copy or store QVideoFrames in JavaScript.
                                function onVideoFrameChanged() {
                                    if (!player.closing && playback.playing) {
                                        playback.receivedFrame = true
                                        frameWatchdog.restart()
                                    }
                                }
                            }

                            // Recycle even apparently healthy players. Slightly
                            // stagger tiles so all four do not go blank together.
                            Timer {
                                id: recyclePlayer
                                interval: Math.max(30000, root.playerLifetimeMs) + tile.index * 5000
                                running: !player.closing
                                repeat: false
                                onTriggered: tile.requestRestart(1500, "Refreshing player...")
                            }

                            // PlaybackState can stay "playing" when a live stream
                            // freezes. Watch actual frame arrivals instead.
                            Timer {
                                id: frameWatchdog
                                interval: 20000
                                running: !player.closing
                                repeat: false
                                onTriggered: tile.requestRetry("No video frame for 20 seconds")
                            }

                            // Reset backoff only after playback has delivered a
                            // frame and stayed playing long enough to recover.
                            Timer {
                                id: healthyPlayback
                                interval: 30000
                                running: playback.playing && playback.receivedFrame && !player.closing
                                repeat: false
                                onTriggered: {
                                    tile.retryDelayMs = 2000
                                    tile.consecutiveFailures = 0
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 24)
                    visible: !decoderLoader.item || !decoderLoader.item.playing
                    text: tile.modelData + "\n" + tile.statusText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: "white"
                    font.pixelSize: 14
                }

                Component.onDestruction: destroying = true
            }
        }
    }
}
