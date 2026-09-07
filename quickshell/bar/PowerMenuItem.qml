import QtQuick
import qs

// One row of the power menu: glyph, label, full-width hover highlight.
Rectangle {
    id: item

    property string glyph: ""
    property string label: ""
    // Shutdown is the only destructive one, so it gets the red treatment.
    property color glyphColor: Theme.colPurpleGlow
    property color labelColor: Theme.colFg

    signal triggered()

    height: 34
    radius: 6
    color: itemMa.containsMouse ? Theme.colHover : "transparent"

    Row {
        anchors.centerIn: parent
        spacing: 10
        Text {
            text: item.glyph
            color: item.glyphColor
            font.family: Theme.fontFamily
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: item.label
            color: item.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: itemMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.triggered()
    }
}
