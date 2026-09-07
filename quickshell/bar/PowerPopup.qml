import QtQuick
import qs
import qs.components
import qs.services

PopupCard {
    id: root
    popupName: "power"
    centerContent: true
    implicitWidth: Theme.powerPopupWidth
    // Fixed rather than content-derived, so the panel doesn't twitch as rows
    // highlight.
    implicitHeight: 184
    anchor.rect.x: root.barWindow ? root.barWindow.width - 8 - Theme.powerPopupWidth : 0

    PowerMenuItem {
        width: parent.width
        glyph: ""
        label: "Lock"
        onTriggered: Session.lock()
    }
    PowerMenuItem {
        width: parent.width
        glyph: "󰤄"
        label: "Sleep"
        onTriggered: {
            Popups.close()
            Session.lock()      // lock before suspending
            Power.sleep()
        }
    }
    PowerMenuItem {
        width: parent.width
        glyph: ""
        label: "Reboot"
        onTriggered: {
            Popups.close()
            Power.reboot()
        }
    }
    PowerMenuItem {
        width: parent.width
        glyph: "⏻"
        label: "Shutdown"
        glyphColor: Theme.colRed
        labelColor: Theme.colRed
        onTriggered: {
            Popups.close()
            Power.shutdown()
        }
    }
}
