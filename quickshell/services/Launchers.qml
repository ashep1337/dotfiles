pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The pinned launchers at the left of the bar, backed by launchers.json.
// bar/PinStrip.qml renders them and drives the drag gestures; this holds the
// model, the file round-trip and the cross-window state for a drag that starts
// in the app launcher and ends on the bar.
Singleton {
    id: launchers

    // A ListModel rather than a plain array because a reorder has to move() a
    // row in place — reassigning an array makes the Repeater tear down every
    // delegate, including the one the drag is holding a grab on.
    property alias model: pinModel
    ListModel { id: pinModel }

    readonly property int count: pinModel.count

    // ── Drag of an existing pin, within the bar ──────────────────────
    // Index of the pin being dragged, or -1. The strip dims the row the ghost
    // was lifted out of.
    property int dragIndex: -1
    // True while the pointer is far enough off the bar that releasing unpins.
    property bool dragRemoving: false

    // ── Drag of a new app in from the launcher ───────────────────────
    // The launcher lives in its own window, so it can't hand the bar a drop
    // event. Instead it publishes the dragged entry plus the pointer in *bar*
    // coordinates, and the strip on the matching screen decides where the
    // insertion caret goes and performs the drop.
    property var pendingEntry: null
    property string pendingScreen: ""
    property real pendingX: 0
    property real pendingY: 0

    signal incomingDropped()

    function beginIncoming(entry, screenName) {
        launchers.pendingScreen = screenName
        launchers.pendingEntry = entry
    }
    function updateIncoming(x, y) {
        launchers.pendingX = x
        launchers.pendingY = y
    }
    // Emitted first so the strip under the pointer can claim the drop, then
    // the state is cleared whether or not anything took it.
    function dropIncoming() {
        if (launchers.pendingEntry) launchers.incomingDropped()
        launchers.cancelIncoming()
    }
    function cancelIncoming() {
        launchers.pendingEntry = null
        launchers.pendingScreen = ""
    }

    // ── launchers.json <-> model ─────────────────────────────────────
    // ListModel fixes its roles from the first row appended, so every row has
    // to carry all of them even when the file omits them. Any key outside this
    // set is parked in `extras` and merged back on write, so hand-added fields
    // survive a rewrite.
    readonly property var knownKeys: ["name", "command", "icon", "fallback", "entry", "extras"]

    function normalize(o) {
        var extras = {}
        for (var k in o)
            if (launchers.knownKeys.indexOf(k) === -1) extras[k] = o[k]
        return {
            name: o.name || "",
            command: o.command || "",
            icon: o.icon || "",
            fallback: o.fallback || "",
            entry: o.entry || "",
            extras: JSON.stringify(extras)
        }
    }

    function serialize() {
        var out = []
        for (var i = 0; i < pinModel.count; i++) {
            var r = pinModel.get(i)
            var o = {}
            if (r.name) o.name = r.name
            if (r.entry) o.entry = r.entry
            if (r.command) o.command = r.command
            if (r.icon) o.icon = r.icon
            if (r.fallback) o.fallback = r.fallback
            var ex = {}
            try {
                ex = JSON.parse(r.extras || "{}")
            } catch (e) {}
            for (var k in ex) o[k] = ex[k]
            out.push(o)
        }
        return out
    }

    // Key-order-independent form of a pin list, used to recognise our own
    // write coming back through the file watcher. Without this, saving would
    // reload and rebuild the model mid-drag.
    function canon(arr) {
        var parts = []
        for (var i = 0; i < arr.length; i++) {
            var o = arr[i]
            var keys = Object.keys(o).sort()
            var kv = []
            for (var j = 0; j < keys.length; j++)
                kv.push(JSON.stringify(keys[j]) + ":" + JSON.stringify(o[keys[j]]))
            parts.push("{" + kv.join(",") + "}")
        }
        return "[" + parts.join(",") + "]"
    }

    function save() {
        launcherFile.setText(JSON.stringify(launchers.serialize(), null, 2) + "\n")
    }

    // ── Mutations ────────────────────────────────────────────────────
    function movePin(from, to) {
        if (from === to) return
        if (from < 0 || to < 0 || from >= pinModel.count || to >= pinModel.count) return
        pinModel.move(from, to, 1)
    }

    function removePin(i) {
        if (i < 0 || i >= pinModel.count) return
        pinModel.remove(i)
        launchers.save()
    }

    function indexOfEntry(id) {
        if (!id) return -1
        for (var i = 0; i < pinModel.count; i++)
            if (pinModel.get(i).entry === id) return i
        return -1
    }

    // Pin a DesktopEntry at `index`. An app that is already pinned moves to the
    // drop position instead of being duplicated.
    function insertEntry(entry, index) {
        if (!entry) return
        index = Math.max(0, Math.min(pinModel.count, index))
        var existing = launchers.indexOfEntry(entry.id)
        if (existing !== -1) {
            // Removing the row first would shift everything after it left.
            if (index > existing) index -= 1
            pinModel.move(existing, index, 1)
        } else {
            pinModel.insert(index, launchers.normalize({
                name: entry.name || entry.id,
                icon: entry.icon || "",
                // No icon resolves to a blank button, so leave a letter behind it.
                fallback: entry.icon ? "" : (entry.name || "?").charAt(0).toUpperCase(),
                entry: entry.id
            }))
        }
        launchers.save()
    }

    function launch(i) {
        var r = pinModel.get(i)
        if (!r) return
        // Going through the desktop entry gets the working directory, terminal
        // handling and startup notification right; `command` is the escape
        // hatch for the hand-written entries that predate pinning.
        if (r.entry) {
            var e = DesktopEntries.byId(r.entry)
            if (e) {
                e.execute()
                return
            }
        }
        if (r.command) Quickshell.execDetached(["sh", "-c", r.command])
    }

    FileView {
        id: launcherFile
        // Resolved against this file's directory, so it has to climb back out
        // of services/ to reach the config root.
        path: Qt.resolvedUrl("../launchers.json")
        blockLoading: true      // populated before the bar first paints
        watchChanges: true
        atomicWrites: true
        onFileChanged: launcherFile.reload()
        onLoaded: {
            var parsed
            try {
                parsed = JSON.parse(launcherFile.text())
            } catch (e) {
                console.error("launchers.json parse error:", e)
                return
            }
            if (!Array.isArray(parsed)) {
                console.error("launchers.json is not an array")
                return
            }
            // Our own save echoing back through the watcher — leave the model
            // (and any in-flight drag) alone.
            if (launchers.canon(parsed) === launchers.canon(launchers.serialize())) return
            pinModel.clear()
            for (var i = 0; i < parsed.length; i++)
                pinModel.append(launchers.normalize(parsed[i]))
        }
        onLoadFailed: err => console.error("launchers.json load failed:", err)
        onSaveFailed: err => console.error("launchers.json save failed:", err)
    }
}
