pragma Singleton

import Quickshell
import QtQuick

// Which bar popup is showing. Only one at a time, so a plain string beats a
// bool per popup — and the bar buttons highlight off the same value.
Singleton {
    id: popups

    // "" | "mail" | "network" | "calendar" | "volume" | "power"
    property string active: ""

    function toggle(name) {
        popups.active = (popups.active === name) ? "" : name
    }
    function close() {
        popups.active = ""
    }
}
