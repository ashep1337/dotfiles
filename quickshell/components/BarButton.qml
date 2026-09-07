import QtQuick
import QtQuick.Layouts
import qs

// A bar widget: rounded, optionally bordered, highlighting on hover or while
// its popup is open. Children are laid out inside it as-is; the click surface
// sits above them, so put interactive children in their own MouseArea.
Rectangle {
    id: btn

    // True while this widget's popup/window is open, so it stays lit.
    property bool active: false
    // Tray and launcher buttons are chrome-less until hovered.
    property bool bordered: true
    property alias acceptedButtons: ma.acceptedButtons
    readonly property alias hovered: ma.containsMouse

    signal clicked(var mouse)
    signal wheeled(var wheel)

    Layout.preferredHeight: 34
    radius: Theme.widgetRadius
    color: (ma.containsMouse || btn.active)
           ? Theme.colHover
           : (btn.bordered ? Theme.colWidgetBg : "transparent")
    border.color: btn.bordered ? Theme.colPurpleBorder : "transparent"
    border.width: btn.bordered ? Theme.borderWidth : 0

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => btn.clicked(mouse)
        onWheel: wheel => btn.wheeled(wheel)
    }
}
