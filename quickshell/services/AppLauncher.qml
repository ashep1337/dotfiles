pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.services

// State for the fullscreen app search (Super+Space). The window that draws it
// is windows/AppLauncherWindow.qml — this holds the query, selection and the
// filtered result list so the bar button can reach them too.
Singleton {
    id: launcher

    property bool open: false
    property string query: ""
    property int index: 0
    property var screen: null

    readonly property var allApps: {
        var a = DesktopEntries.applications
        if (!a) return []
        return (a.values !== undefined) ? a.values : a
    }

    function matches(query) {
        var q = query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < launcher.allApps.length; i++) {
            var e = launcher.allApps[i]
            if (!e || e.noDisplay) continue
            if (q !== "") {
                var hay = ((e.name || "") + " " + (e.genericName || "") + " "
                           + (e.comment || "") + " " + (e.id || "")).toLowerCase()
                if (hay.indexOf(q) === -1) continue
            }
            out.push(e)
        }
        // Name-prefix hits float to the top, then alphabetical
        out.sort(function (a, b) {
            var an = (a.name || "").toLowerCase()
            var bn = (b.name || "").toLowerCase()
            var ap = an.indexOf(q) === 0 ? 0 : 1
            var bp = bn.indexOf(q) === 0 ? 0 : 1
            if (ap !== bp) return ap - bp
            return an < bn ? -1 : (an > bn ? 1 : 0)
        })
        return out
    }

    readonly property var results: launcher.matches(launcher.query)

    function focusedScreen() {
        var fm = Hyprland.focusedMonitor
        if (fm) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === fm.name) return Quickshell.screens[i]
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function show() {
        launcher.query = ""
        launcher.index = 0
        launcher.screen = launcher.focusedScreen()
        launcher.open = true
    }
    function close() {
        launcher.open = false
        launcher.query = ""
        launcher.index = 0
    }
    function toggle() {
        if (Session.locked) return
        if (launcher.open) launcher.close()
        else launcher.show()
    }

    function run(entry) {
        if (!entry) return
        launcher.close()
        entry.execute()
    }

    function moveIndex(delta) {
        var n = launcher.results.length
        if (n === 0) { launcher.index = 0; return }
        launcher.index = Math.max(0, Math.min(n - 1, launcher.index + delta))
    }
}
