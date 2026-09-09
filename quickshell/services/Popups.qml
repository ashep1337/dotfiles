pragma Singleton

import Quickshell
import QtQuick

// Which bar popup is showing. Only one at a time, so a plain string beats a
// bool per popup — and the bar buttons highlight off the same value.
Singleton {
    id: popups

    // "" | "mail" | "network" | "calendar" | "volume" | "power"
    property string active: ""

    // Which bar the open popup belongs to. Every screen has its own bar and
    // therefore its own copy of every popup, so without this the same popup
    // would show on all of them at once — and every bar would try to take the
    // focus grab, each new grab clearing the last one's.
    property string screenName: ""

    function toggle(name, screen) {
        var s = screen || ""
        if (popups.active === name && popups.screenName === s) {
            popups.close()
            return
        }
        // Name first, then screen: a popup going invisible because the screen
        // changed must not look like a compositor dismissal to PopupCard.
        popups.active = name
        popups.screenName = s
    }
    function close() {
        popups.active = ""
        popups.screenName = ""
    }
}
