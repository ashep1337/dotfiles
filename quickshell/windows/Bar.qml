import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.components
import qs.services

// One bar per screen. Instantiated from shell.qml inside a Variants block,
// which is what feeds `modelData`.
PanelWindow {
    id: barWindow
    property var modelData
    screen: modelData
    readonly property string screenName: modelData ? modelData.name : ""

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.colBarBg

    // Importing Quickshell.Services.SystemTray registers this shell as the
    // StatusNotifier host, which is what makes tray icons appear at all.
    readonly property var trayItems: {
        var t = SystemTray.items
        if (!t) return []
        return (t.values !== undefined) ? t.values : t
    }

    // ── Click-outside overlay to dismiss popups ──────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: Popups.active !== ""
        z: 1
        onClicked: Popups.close()
    }

    // ── Popups ───────────────────────────────────────────────────────
    // Each pins its own x against the bar's right edge; see PopupCard.
    MailPopup     { id: mailPopup;     barWindow: barWindow }
    NetworkPopup  { id: networkPopup;  barWindow: barWindow }
    CalendarPopup { id: calendarPopup; barWindow: barWindow }
    VolumePopup   { id: volumePopup;   barWindow: barWindow }
    PowerPopup    { id: powerPopup;    barWindow: barWindow }

    // ── Click-outside dismissal ──────────────────────────────────────
    // A PopupWindow never takes focus, so nothing tells it that a click landed
    // somewhere else on the screen. The compositor-side grab does: while it
    // holds, clicks still reach this bar and the open popup, and the first
    // click anywhere else clears the grab instead of reaching what was under
    // it. Being a grab rather than a focus watch is what makes this survive
    // focus-follows-mouse — merely moving the pointer away does nothing.
    readonly property var openPopup: {
        if (Popups.screenName !== barWindow.screenName) return null
        switch (Popups.active) {
        case "mail":     return mailPopup
        case "network":  return networkPopup
        case "calendar": return calendarPopup
        case "volume":   return volumePopup
        case "power":    return powerPopup
        }
        return null
    }

    HyprlandFocusGrab {
        active: barWindow.openPopup !== null
        windows: barWindow.openPopup ? [barWindow, barWindow.openPopup] : []
        // Hyprland also clears the grab when we drop it ourselves; closing an
        // already-closed popup is harmless.
        onCleared: Popups.close()
    }

    // ── Main bar layout ──────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 6
        z: 2

        // ═════════════════════════════════════════════════════════════
        //  LEFT: App launcher (Arch logo) + Dynamic launchers
        // ═════════════════════════════════════════════════════════════
        BarButton {
            Layout.preferredWidth: 36
            active: AppLauncher.open
            onClicked: AppLauncher.toggle()
            Item {
                anchors.centerIn: parent
                width: Theme.iconSize
                height: Theme.iconSize
                // Glyph sits behind the icon and shows through if the themed
                // icon can't be resolved.
                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    color: Theme.colPurpleGlow
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                }
                IconImage {
                    anchors.fill: parent
                    source: "image://icon/archlinux-logo"
                }
            }
        }

        BarSeparator {}

        // ── Pinned launchers from launchers.json ─────────────────────
        // Drag to reorder, drag off the bar to unpin, drop an app from the
        // launcher to pin it.
        PinStrip {
            screenName: barWindow.screenName
        }

        Item { Layout.fillWidth: true }

        // ═════════════════════════════════════════════════════════════
        //  CENTER: Time & Date (12hr) — click for calendar
        // ═════════════════════════════════════════════════════════════
        BarButton {
            Layout.preferredWidth: clockRow.implicitWidth + 24
            onClicked: Popups.toggle("calendar", barWindow.screenName)
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "  " + Clock.currentTime
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 1
                    height: 18
                    color: Theme.colPurpleBorder
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Clock.currentDate
                    color: Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ═════════════════════════════════════════════════════════════
        //  RIGHT: Mail, Ask, Signal, Tray, Network, Volume, Power
        // ═════════════════════════════════════════════════════════════
        BarButton {
            Layout.preferredWidth: mailRow.implicitWidth + 20
            active: Popups.active === "mail"
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                // Right-click forces a refresh without waiting out the
                // two-minute poll.
                if (mouse.button === Qt.RightButton) Gmail.check()
                else Popups.toggle("mail", barWindow.screenName)
            }
            Row {
                id: mailRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: Gmail.count > 0 ? "󰇮" : "󰇯"
                    color: Gmail.error !== "" ? Theme.colRed
                         : (Gmail.count > 0 ? Theme.colPurpleGlow : Theme.colFgDim)
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: Gmail.count > 0
                    text: Gmail.count
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        BarButton {
            Layout.preferredWidth: 36
            active: Ask.open
            onClicked: Ask.toggle()
            Text {
                anchors.centerIn: parent
                text: "󰭹"
                color: Ask.busy ? Theme.colGreen : Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
        }

        BarButton {
            Layout.preferredWidth: signalRow.implicitWidth + 20
            active: Signal.open
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                // Right-click restarts the signal-cli child, for when the
                // connection has gone stale.
                if (mouse.button === Qt.RightButton) Signal.reconnect()
                else Signal.toggle()
            }
            Row {
                id: signalRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "󰍡"
                    color: Signal.status === "error" ? Theme.colRed
                         : (Signal.unreadTotal > 0 ? Theme.colPurpleGlow
                                                   : (Signal.online ? Theme.colFg
                                                                    : Theme.colFgDim))
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: Signal.unreadTotal > 0
                    text: Signal.unreadTotal
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Repeater {
            model: barWindow.trayItems
            BarButton {
                id: trayBtn
                required property var modelData
                required property int index
                Layout.preferredWidth: 30
                bordered: false
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (trayBtn.modelData.hasMenu) trayMenu.open()
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayBtn.modelData.secondaryActivate()
                    } else {
                        // onlyMenu items have no activate action
                        if (trayBtn.modelData.onlyMenu) {
                            if (trayBtn.modelData.hasMenu) trayMenu.open()
                        } else {
                            trayBtn.modelData.activate()
                        }
                    }
                }
                IconImage {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayBtn.modelData.icon
                }
                // NeedsAttention items get the same red dot treatment
                Rectangle {
                    visible: trayBtn.modelData.status === Status.NeedsAttention
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 3
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.colRed
                }
                // Renders the app's own D-Bus menu
                QsMenuAnchor {
                    id: trayMenu
                    menu: trayBtn.modelData.menu
                    anchor.item: trayBtn
                }
            }
        }

        BarSeparator {
            visible: barWindow.trayItems.length > 0
        }

        BarButton {
            Layout.preferredWidth: netRow.implicitWidth + 20
            onClicked: Popups.toggle("network", barWindow.screenName)
            Row {
                id: netRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: Network.connected ? "󰤨" : "󰤭"
                    color: Network.connected ? Theme.colPurpleGlow : Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Network.name
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        BarButton {
            Layout.preferredWidth: volRow.implicitWidth + 20
            onClicked: Popups.toggle("volume", barWindow.screenName)
            onWheeled: wheel => Audio.nudge(wheel.angleDelta.y > 0 ? 5 : -5)
            Row {
                id: volRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: Audio.muted ? "󰖁"
                        : (Audio.display > 50 ? "󰕾" : (Audio.display > 0 ? "󰖀" : "󰕿"))
                    color: Audio.muted ? Theme.colFgDim : Theme.colPurpleGlow
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Audio.display + "%"
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        BarSeparator {}

        BarButton {
            Layout.preferredWidth: 36
            onClicked: Popups.toggle("power", barWindow.screenName)
            Text {
                anchors.centerIn: parent
                text: "⏻"
                color: Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
        }
    }
}
