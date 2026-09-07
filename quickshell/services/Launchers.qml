pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The quick-launch buttons on the left of the bar, read from launchers.json.
// FileView replaces `cat` + SplitParser. watchChanges means edits to
// launchers.json apply without reloading the shell.
Singleton {
    id: launchers

    property var items: []

    FileView {
        id: launcherFile
        // Resolved against this file's directory, so it has to climb back out
        // of services/ to reach the config root.
        path: Qt.resolvedUrl("../launchers.json")
        blockLoading: true      // populated before the bar first paints
        watchChanges: true
        onFileChanged: launcherFile.reload()
        onLoaded: {
            try {
                launchers.items = JSON.parse(launcherFile.text())
            } catch (e) {
                console.error("launchers.json parse error:", e)
            }
        }
        onLoadFailed: err => console.error("launchers.json load failed:", err)
    }
}
