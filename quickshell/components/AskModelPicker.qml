import QtQuick
import qs
import qs.services

// Left-click cycles forward, right-click back, Ctrl+M from the input.
Rectangle {
    width: modelLabel.implicitWidth + 22
    height: 22
    radius: 11
    color: modelMa.containsMouse ? Theme.colHover : Theme.colPopupInset
    border.color: Theme.colPurpleBorder
    border.width: 1
    Text {
        id: modelLabel
        anchors.centerIn: parent
        text: "󰧑 " + Ask.modelLabel
        color: Theme.colFg
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    MouseArea {
        id: modelMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Ask.cycleModel(mouse.button === Qt.RightButton ? -1 : 1)
    }
}
