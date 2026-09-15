import QtQuick
import qs
import qs.services

// Left-click cycles forward, right-click back, Ctrl+M from the input.
Rectangle {
    width: Math.min(labelMetrics.width + 22, 210)
    height: 22
    radius: 11
    color: modelMa.containsMouse ? Theme.colHover : Theme.colPopupInset
    border.color: Theme.colPurpleBorder
    border.width: 1
    TextMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 11
        text: "󰧑 " + Ask.modelLabel
    }
    Text {
        id: modelLabel
        anchors.centerIn: parent
        width: parent.width - 22
        elide: Text.ElideRight
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
        enabled: !Ask.busy
        onClicked: mouse => Ask.cycleModel(mouse.button === Qt.RightButton ? -1 : 1)
    }
}
