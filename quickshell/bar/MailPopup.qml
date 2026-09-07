import QtQuick
import qs
import qs.components
import qs.services

PopupCard {
    id: root
    popupName: "mail"
    implicitWidth: Theme.mailPopupWidth
    anchor.rect.x: root.barWindow ? root.barWindow.width - 260 - Theme.mailPopupWidth : 0

    Row {
        width: parent.width
        spacing: 6
        Text {
            text: "󰇰  Inbox"
            color: Theme.colPurpleGlow
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - 170; height: 1 }
        Text {
            text: Gmail.checking ? "checking…" : (Gmail.count + " unread")
            color: Theme.colFgDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Divider { width: parent.width }

    Text {
        visible: Gmail.error !== ""
        width: parent.width
        text: Gmail.error
        color: Theme.colRed
        font.family: Theme.fontFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
        topPadding: 4
        bottomPadding: 4
    }

    // Capped height with clipping, so a full inbox scrolls instead of
    // running off the screen.
    ListView {
        id: mailList
        width: parent.width
        height: Math.min(contentHeight, 420)
        visible: Gmail.messages.length > 0
        clip: true
        model: Gmail.messages
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        delegate: Rectangle {
            id: mailRow
            required property var modelData
            width: mailList.width
            height: 46
            radius: 6
            color: mailRowMa.containsMouse ? Theme.colPopupHover : "transparent"
            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                width: parent.width - 12
                spacing: 1
                Row {
                    width: parent.width
                    spacing: 6
                    Text {
                        text: mailRow.modelData.from
                        color: Theme.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        width: parent.width - 78
                        elide: Text.ElideRight
                    }
                    Text {
                        text: mailRow.modelData.date || ""
                        color: Theme.colFgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        width: 72
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }
                Text {
                    text: mailRow.modelData.subject
                    color: Theme.colFgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: mailRowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.close()          // the reader is its own window
                    Gmail.openBody(mailRow.modelData)
                }
            }
        }
    }

    // Shown when the true unread total exceeds what we fetched
    Text {
        visible: Gmail.count > Gmail.messages.length
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "+ " + (Gmail.count - Gmail.messages.length) + " more in Gmail"
        color: Theme.colFgDim
        font.family: Theme.fontFamily
        font.pixelSize: 10
        topPadding: 2
    }
    Text {
        visible: Gmail.messages.length === 0 && Gmail.error === "" && !Gmail.checking
        text: "No unread mail"
        color: Theme.colFgDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        topPadding: 6
        bottomPadding: 6
    }
    Divider { width: parent.width }
    Rectangle {
        width: parent.width
        height: 28
        radius: 6
        color: mailOpenMa.containsMouse ? Theme.colHover : "transparent"
        Text {
            anchors.centerIn: parent
            text: "Open Gmail"
            color: Theme.colFg
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        MouseArea {
            id: mailOpenMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Popups.close()
                Gmail.openInBrowser("https://mail.google.com/")
            }
        }
    }
}
