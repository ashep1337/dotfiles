import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components
import qs.services

// A FloatingWindow like the chat panel, so Hyprland places and focuses it
// normally and it isn't cramped inside the bar popup.
FloatingWindow {
    id: mailReader
    title: "Mail"
    visible: Gmail.bodyUid !== ""
    implicitWidth: 900
    implicitHeight: 700
    color: Theme.colPopupBg

    // ── Click-outside dismissal ──────────────────────────────────────
    // Focus-follows-mouse rules out closing on focus loss: the pointer merely
    // crossing the border would count. A compositor-side grab clears on a
    // button press outside the window instead, so drifting the mouse away
    // leaves the window alone. That first click outside is spent on the
    // dismissal and does not reach whatever was under it.
    HyprlandFocusGrab {
        active: mailReader.visible
        windows: [mailReader]
        // Hyprland clears the grab when we drop it too — after the window is
        // already hidden — so re-check before acting on it.
        onCleared: if (mailReader.visible) Gmail.closeBody()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colPopupBg
        border.color: Theme.colPurpleBorder
        border.width: Theme.borderWidth
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ── Header ───────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 10
                Text {
                    text: "󰇮  Message"
                    color: Theme.colPurpleGlow
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - 300; height: 1 }
                Text {
                    text: Gmail.bodyLoading ? "loading…" : Gmail.bodyDate
                    color: Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 68
                    height: 26
                    radius: 6
                    color: mailCloseMa.containsMouse ? Theme.colHover : "transparent"
                    border.color: Theme.colPurpleBorder
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: mailCloseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Gmail.closeBody()
                    }
                }
            }

            Text {
                text: Gmail.bodyFrom
                color: Theme.colFg
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                width: parent.width
                elide: Text.ElideRight
            }
            Text {
                text: Gmail.bodySubject
                color: Theme.colPurpleGlow
                font.family: Theme.fontFamily
                font.pixelSize: 14
                width: parent.width
                wrapMode: Text.Wrap
            }
            Divider { width: parent.width }

            // ── Body ─────────────────────────────────────────────────
            Flickable {
                id: mailBodyFlick
                width: parent.width
                height: parent.height - 190
                clip: true
                contentHeight: mailBodyText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: mailBodyText
                    width: mailBodyFlick.width
                    readOnly: true
                    selectByMouse: true
                    selectionColor: Theme.colPurple
                    selectedTextColor: Theme.colFg
                    text: Gmail.bodyError !== "" ? Gmail.bodyError
                        : (Gmail.bodyLoading ? "…" : Gmail.bodyText)
                    color: Gmail.bodyError !== "" ? Theme.colRed : Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    Keys.onEscapePressed: Gmail.closeBody()
                }
            }

            Divider { width: parent.width }

            Rectangle {
                width: parent.width
                height: 32
                radius: 6
                color: mailGmailMa.containsMouse ? Theme.colHover : "transparent"
                border.color: Theme.colPurpleBorder
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Open this in Gmail"
                    color: Theme.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                MouseArea {
                    id: mailGmailMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Popups.close()
                        Gmail.openCurrentInGmail()
                    }
                }
            }
        }
    }
}
