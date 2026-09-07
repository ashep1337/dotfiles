import QtQuick
import qs
import qs.services

// Quick ⇄ Chat toggle, shared by both Ask windows.
Row {
    spacing: 8
    Text {
        text: "Quick"
        color: Ask.chat ? Theme.colFgDim : Theme.colFg
        font.family: Theme.fontFamily
        font.pixelSize: 11
        anchors.verticalCenter: parent.verticalCenter
    }
    Rectangle {
        width: 42
        height: 22
        radius: 11
        color: Ask.chat ? Theme.colPurple : Theme.colPopupInset
        border.color: Theme.colPurpleBorder
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: Ask.chat ? parent.width - width - 3 : 3
            color: Theme.colFg
            Behavior on x {
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Ask.setMode(!Ask.chat)
        }
    }
    Text {
        text: "Chat"
        color: Ask.chat ? Theme.colFg : Theme.colFgDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        anchors.verticalCenter: parent.verticalCenter
    }
}
